import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const NOTE = ethers.zeroPadValue("0x01", 32);
const NOTE2 = ethers.zeroPadValue("0x02", 32);
const NOTE3 = ethers.zeroPadValue("0x03", 32);
const NOTE4 = ethers.zeroPadValue("0x04", 32);
const NOTE5 = ethers.zeroPadValue("0x05", 32);
const NOTE6 = ethers.zeroPadValue("0x06", 32);
const FINALIZER = ethers.zeroPadValue("0xaa", 32);
const FINALIZER_B = ethers.zeroPadValue("0xbb", 32);

function uaHash(ua: string): string {
  return ethers.keccak256(ethers.toUtf8Bytes(ua));
}

const SAMPLE_UA = `u1${"h".repeat(76)}`;
const DONATION_UA = `u1${"d".repeat(76)}`;
const DAY = 86400;
const MIN_LOCK = 30 * DAY;
const YEAR = 365 * DAY;

describe("IronwoodLegacyVault", () => {
  async function deploy() {
    const [owner, trustee, manager, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("IronwoodLegacyVault");
    const vault = await Factory.deploy(DONATION_UA);
    await vault.waitForDeployment();
    const heir = uaHash(SAMPLE_UA);
    return { vault, owner, trustee, manager, other, heir };
  }

  async function openVault(
    vault: Awaited<ReturnType<typeof deploy>>["vault"],
    owner: Awaited<ReturnType<typeof deploy>>["owner"],
    args: {
      note: string;
      duration: number;
      heir: string;
      trustee: string;
      manager: string;
      finalizer?: string;
    },
  ) {
    await vault.createVault(
      args.note,
      args.duration,
      args.finalizer ?? FINALIZER,
      args.manager,
      [args.heir],
      [args.trustee],
      "lock",
    );
    return (await vault.vaultsOf(owner.address)).at(-1)!;
  }

  it("stores an Ironwood donation UA (not an ETH address)", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    expect(await vault.donationUa()).to.equal(DONATION_UA);
    expect(await vault.donationUaHash()).to.equal(uaHash(DONATION_UA));
    const id = await openVault(vault, owner, {
      note: NOTE,
      duration: MIN_LOCK,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    const view = await vault.getVault(id);
    expect(view.stakedToFinalizer).to.equal(true);
    expect(view.penaltyBps).to.equal(0);
  });

  it("rejects an ETH address as the donation UA", async () => {
    const { vault } = await deploy();
    const Factory = await ethers.getContractFactory("IronwoodLegacyVault");
    await expect(
      Factory.deploy("0x0000000000000000000000000000000000000001"),
    ).to.be.revertedWithCustomError(vault, "InvalidIronwoodAddress");
  });

  it("rejects locks shorter than 30 days", async () => {
    const { vault, trustee, manager, heir } = await deploy();
    await expect(
      vault.createVault(
        NOTE,
        MIN_LOCK - DAY,
        FINALIZER,
        manager.address,
        [heir],
        [trustee.address],
        "",
      ),
    ).to.be.revertedWithCustomError(vault, "InvalidDuration");
  });

  it("rejects locks longer than 30 years", async () => {
    const { vault, trustee, manager, heir } = await deploy();
    await expect(
      vault.createVault(
        NOTE,
        30 * YEAR + DAY,
        FINALIZER,
        manager.address,
        [heir],
        [trustee.address],
        "",
      ),
    ).to.be.revertedWithCustomError(vault, "InvalidDuration");
  });

  it("accepts a 30 year lock", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: NOTE2,
      duration: 30 * YEAR,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    const view = await vault.getVault(id);
    expect(view.unlockAt).to.equal(view.createdAt + BigInt(30 * YEAR));
  });

  it("owner and manager can check in while staked; stranger cannot", async () => {
    const { vault, owner, trustee, manager, other, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: NOTE3,
      duration: YEAR,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await expect(vault.checkIn(id)).to.emit(vault, "StakingCheckIn");
    await expect(vault.connect(manager).checkIn(id)).to.emit(vault, "StakingCheckIn");
    await expect(vault.connect(other).checkIn(id)).to.be.revertedWithCustomError(
      vault,
      "NotAuthorized",
    );
  });

  it("missed check-in recalls from the finalizer and stays locked until unlockAt", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: NOTE4,
      duration: YEAR,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await expect(vault.connect(trustee).recallFromFinalizer(id)).to.be.revertedWithCustomError(
      vault,
      "CheckInStillValid",
    );
    await time.increase(30 * DAY + 1);
    await expect(vault.connect(trustee).recallFromFinalizer(id)).to.emit(
      vault,
      "RecalledFromFinalizer",
    );
    const view = await vault.getVault(id);
    expect(view.stakedToFinalizer).to.equal(false);
    expect(view.released).to.equal(false);
    await expect(vault.markReleased(id)).to.be.revertedWithCustomError(vault, "TooEarly");
    await expect(vault.checkIn(id)).to.be.revertedWithCustomError(vault, "NotStaked");
  });

  it("owner can restake to a new finalizer after recall", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: NOTE5,
      duration: YEAR,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await time.increase(30 * DAY + 1);
    await vault.recallFromFinalizer(id);
    await expect(vault.restakeToFinalizer(id, FINALIZER_B)).to.emit(vault, "RestakedToFinalizer");
    const view = await vault.getVault(id);
    expect(view.stakedToFinalizer).to.equal(true);
    expect(view.finalizer).to.equal(FINALIZER_B);
  });

  it("scheduled release after unlock has 0% penalty", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: NOTE6,
      duration: MIN_LOCK,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await time.increase(MIN_LOCK);
    await expect(vault.markReleased(id)).to.emit(vault, "VaultReleased");
    const view = await vault.getVault(id);
    expect(view.released).to.equal(true);
    expect(view.earlyRelease).to.equal(false);
    expect(view.penaltyBps).to.equal(0);
    expect(view.stakedToFinalizer).to.equal(false);
  });

  it("early release attests 10% to the Ironwood donation UA", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: ethers.zeroPadValue("0x07", 32),
      duration: YEAR,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await expect(vault.earlyRelease(id))
      .to.emit(vault, "VaultReleased")
      .withArgs(id, owner.address, ethers.zeroPadValue("0x07", 32), true, 1000);
    const view = await vault.getVault(id);
    expect(view.earlyRelease).to.equal(true);
    expect(view.penaltyBps).to.equal(1000);
    expect(await vault.donationUa()).to.equal(DONATION_UA);
  });

  it("cannot early-release after the lock has matured", async () => {
    const { vault, owner, trustee, manager, heir } = await deploy();
    const id = await openVault(vault, owner, {
      note: ethers.zeroPadValue("0x08", 32),
      duration: MIN_LOCK,
      heir,
      trustee: trustee.address,
      manager: manager.address,
    });
    await time.increase(MIN_LOCK);
    await expect(vault.earlyRelease(id)).to.be.revertedWithCustomError(vault, "TooEarly");
  });

  it("rejects a duplicate note commitment", async () => {
    const { vault, trustee, manager, heir } = await deploy();
    await vault.createVault(
      NOTE,
      MIN_LOCK,
      FINALIZER,
      manager.address,
      [heir],
      [trustee.address],
      "",
    );
    await expect(
      vault.createVault(NOTE, MIN_LOCK, FINALIZER, manager.address, [heir], [trustee.address], ""),
    ).to.be.revertedWithCustomError(vault, "NoteAlreadyVaulted");
  });

  it("hashUnifiedAddress is keccak256 of the Ironwood UA string", async () => {
    const { vault } = await deploy();
    expect(await vault.hashUnifiedAddress(SAMPLE_UA)).to.equal(uaHash(SAMPLE_UA));
  });
});

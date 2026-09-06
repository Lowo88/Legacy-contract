import { ethers } from "hardhat";

async function main() {
  const donationUa = process.env.DONATION_UA;
  if (!donationUa) {
    throw new Error("Set DONATION_UA to an Ironwood unified address (u1… or utest1…)");
  }
  const Vault = await ethers.getContractFactory("IronwoodLegacyVault");
  const vault = await Vault.deploy(donationUa);
  await vault.waitForDeployment();
  console.log("IronwoodLegacyVault:", await vault.getAddress());
  console.log("donationUa:", await vault.donationUa());
  console.log("donationUaHash:", await vault.donationUaHash());
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

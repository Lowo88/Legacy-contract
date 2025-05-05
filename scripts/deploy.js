const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy Halo2Verifier
  console.log("Deploying Halo2Verifier...");
  const Halo2Verifier = await hre.ethers.getContractFactory("Halo2Verifier");
  const halo2Verifier = await Halo2Verifier.deploy();
  await halo2Verifier.waitForDeployment();
  console.log("Halo2Verifier deployed to:", await halo2Verifier.getAddress());

  // Deploy Legacy
  console.log("Deploying Legacy...");
  const Legacy = await hre.ethers.getContractFactory("Legacy");
  const legacy = await Legacy.deploy(await halo2Verifier.getAddress());
  await legacy.waitForDeployment();
  console.log("Legacy deployed to:", await legacy.getAddress());

  // Deploy LegacyAI
  console.log("Deploying LegacyAI...");
  const LegacyAI = await hre.ethers.getContractFactory("LegacyAI");
  const legacyAI = await LegacyAI.deploy(await legacy.getAddress());
  await legacyAI.waitForDeployment();
  console.log("LegacyAI deployed to:", await legacyAI.getAddress());

  // Deploy ZCashIntegration
  console.log("Deploying ZCashIntegration...");
  const ZCashIntegration = await hre.ethers.getContractFactory("ZCashIntegration");
  const zcashIntegration = await ZCashIntegration.deploy(await halo2Verifier.getAddress());
  await zcashIntegration.waitForDeployment();
  console.log("ZCashIntegration deployed to:", await zcashIntegration.getAddress());

  // Deploy ZKRollup
  console.log("Deploying ZKRollup...");
  const ZKRollup = await hre.ethers.getContractFactory("ZKRollup");
  const zkRollup = await ZKRollup.deploy(
    await halo2Verifier.getAddress(),
    await zcashIntegration.getAddress()
  );
  await zkRollup.waitForDeployment();
  console.log("ZKRollup deployed to:", await zkRollup.getAddress());

  // Verify contracts on Etherscan
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await halo2Verifier.deployTransaction.wait(6);
    await legacy.deployTransaction.wait(6);
    await legacyAI.deployTransaction.wait(6);
    await zcashIntegration.deployTransaction.wait(6);
    await zkRollup.deployTransaction.wait(6);

    console.log("Verifying contracts...");
    await hre.run("verify:verify", {
      address: await halo2Verifier.getAddress(),
      constructorArguments: [],
    });

    await hre.run("verify:verify", {
      address: await legacy.getAddress(),
      constructorArguments: [await halo2Verifier.getAddress()],
    });

    await hre.run("verify:verify", {
      address: await legacyAI.getAddress(),
      constructorArguments: [await legacy.getAddress()],
    });

    await hre.run("verify:verify", {
      address: await zcashIntegration.getAddress(),
      constructorArguments: [await halo2Verifier.getAddress()],
    });

    await hre.run("verify:verify", {
      address: await zkRollup.getAddress(),
      constructorArguments: [
        await halo2Verifier.getAddress(),
        await zcashIntegration.getAddress(),
      ],
    });
  }

  console.log("All contracts deployed and verified successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 
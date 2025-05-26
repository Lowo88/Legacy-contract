const { ethers } = require("hardhat");
const { Wallet } = require("zksync-web3");
const { HardhatRuntimeEnvironment } = require("hardhat/types");
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");

// Load environment variables
require("dotenv").config();

// zkSync addresses (mainnet)
const ZKSYNC_MAINNET = {
    zkSync: "0x32400084C286CF3E17e7B677ea9583e60a000324",
    l1Bridge: "0x57891966931Eb4Bb6FB81430E6cE0A03AAbDe063",
    l2Bridge: "0x11f943b2c77d7438C7D9BF4415d225d161844925"
};

// zkSync addresses (testnet)
const ZKSYNC_TESTNET = {
    zkSync: "0x1908e2BF4a88F91E4eF0DC72f02b8Ea36BEa2319",
    l1Bridge: "0x927DdFcc51Ebf25431c60bA0dD9c0ed3C2869C9D",
    l2Bridge: "0x11f943b2c77d7438C7D9BF4415d225d161844925"
};

async function main() {
    const hre = require("hardhat");
    const network = hre.network.name;
    
    console.log(`Deploying LegacyZkSync to ${network}...`);

    // Get the deployer's wallet
    const wallet = new Wallet(process.env.PRIVATE_KEY);
    const deployer = new Deployer(hre, wallet);

    // Get the contract artifact
    const artifact = await deployer.loadArtifact("LegacyZkSync");

    // Get the LGC token address
    const lgcToken = await ethers.getContract("LegacyToken");
    console.log("LGC Token address:", lgcToken.address);

    // Get the Halo2 verifier address
    const halo2Verifier = await ethers.getContract("Halo2Verifier");
    console.log("Halo2 Verifier address:", halo2Verifier.address);

    // Get the appropriate zkSync addresses
    const zkSyncAddresses = network === "mainnet" ? ZKSYNC_MAINNET : ZKSYNC_TESTNET;

    // Deploy the contract
    const legacyZkSync = await deployer.deploy(artifact, [
        zkSyncAddresses.zkSync,
        zkSyncAddresses.l1Bridge,
        zkSyncAddresses.l2Bridge,
        lgcToken.address,
        halo2Verifier.address
    ]);

    // Wait for deployment to finish
    await legacyZkSync.deployed();

    console.log("LegacyZkSync deployed to:", legacyZkSync.address);

    // Verify the contract on Etherscan
    if (network !== "hardhat" && network !== "localhost") {
        console.log("Waiting for block confirmations...");
        await legacyZkSync.deployTransaction.wait(6);

        console.log("Verifying contract...");
        await hre.run("verify:verify", {
            address: legacyZkSync.address,
            constructorArguments: [
                zkSyncAddresses.zkSync,
                zkSyncAddresses.l1Bridge,
                zkSyncAddresses.l2Bridge,
                lgcToken.address,
                halo2Verifier.address
            ],
        });
    }

    // Save deployment info
    const deploymentInfo = {
        network,
        contract: "LegacyZkSync",
        address: legacyZkSync.address,
        deployer: wallet.address,
        zkSync: zkSyncAddresses.zkSync,
        l1Bridge: zkSyncAddresses.l1Bridge,
        l2Bridge: zkSyncAddresses.l2Bridge,
        lgcToken: lgcToken.address,
        halo2Verifier: halo2Verifier.address,
        timestamp: new Date().toISOString()
    };

    // Save to deployment-info.json
    const fs = require("fs");
    const path = require("path");
    const deploymentPath = path.join(__dirname, "../deployment-info.json");
    
    let deployments = {};
    if (fs.existsSync(deploymentPath)) {
        deployments = JSON.parse(fs.readFileSync(deploymentPath));
    }
    
    deployments[network] = deployments[network] || {};
    deployments[network].LegacyZkSync = deploymentInfo;
    
    fs.writeFileSync(deploymentPath, JSON.stringify(deployments, null, 2));
    console.log("Deployment info saved to deployment-info.json");
}

// Run the deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 
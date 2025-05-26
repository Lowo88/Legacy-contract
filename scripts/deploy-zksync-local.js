const { ethers } = require("hardhat");
const { Wallet } = require("zksync-web3");
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");

async function main() {
    console.log("Deploying LegacyZkSync to local network...");

    // Get the deployer's wallet
    const [signer] = await ethers.getSigners();
    const wallet = new Wallet(signer.privateKey);
    const zkDeployer = new Deployer(hre, wallet);

    // Deploy mock LGC token
    const LegacyToken = await ethers.getContractFactory("LegacyToken");
    const lgcToken = await LegacyToken.deploy();
    await lgcToken.deployed();
    console.log("Mock LGC Token deployed to:", lgcToken.address);

    // Deploy mock Halo2 verifier
    const Halo2Verifier = await ethers.getContractFactory("Halo2Verifier");
    const halo2Verifier = await Halo2Verifier.deploy();
    await halo2Verifier.deployed();
    console.log("Mock Halo2 Verifier deployed to:", halo2Verifier.address);

    // Deploy mock zkSync contracts
    const MockZkSync = await ethers.getContractFactory("MockZkSync");
    const mockZkSync = await MockZkSync.deploy();
    await mockZkSync.deployed();
    console.log("Mock zkSync deployed to:", mockZkSync.address);

    const MockL1Bridge = await ethers.getContractFactory("MockL1Bridge");
    const mockL1Bridge = await MockL1Bridge.deploy();
    await mockL1Bridge.deployed();
    console.log("Mock L1 Bridge deployed to:", mockL1Bridge.address);

    const MockL2Bridge = await ethers.getContractFactory("MockL2Bridge");
    const mockL2Bridge = await MockL2Bridge.deploy();
    await mockL2Bridge.deployed();
    console.log("Mock L2 Bridge deployed to:", mockL2Bridge.address);

    // Get the LegacyZkSync artifact
    const artifact = await zkDeployer.loadArtifact("LegacyZkSync");

    // Deploy LegacyZkSync
    const legacyZkSync = await zkDeployer.deploy(artifact, [
        mockZkSync.address,
        mockL1Bridge.address,
        mockL2Bridge.address,
        lgcToken.address,
        halo2Verifier.address
    ]);

    // Wait for deployment to finish
    await legacyZkSync.deployed();

    console.log("LegacyZkSync deployed to:", legacyZkSync.address);

    // Save deployment info
    const deploymentInfo = {
        network: "localhost",
        contract: "LegacyZkSync",
        address: legacyZkSync.address,
        deployer: signer.address,
        zkSync: mockZkSync.address,
        l1Bridge: mockL1Bridge.address,
        l2Bridge: mockL2Bridge.address,
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
    
    deployments.localhost = deployments.localhost || {};
    deployments.localhost.LegacyZkSync = deploymentInfo;
    
    fs.writeFileSync(deploymentPath, JSON.stringify(deployments, null, 2));
    console.log("Deployment info saved to deployment-info.json");

    // Log test instructions
    console.log("\nTest Instructions:");
    console.log("1. Fund the deployer account with some ETH");
    console.log("2. Mint some LGC tokens to the deployer account");
    console.log("3. Register as a user using registerUser()");
    console.log("4. Try depositing LGC tokens to zkSync");
    console.log("5. Try transferring tokens on zkSync");
    console.log("6. Try withdrawing tokens from zkSync");
}

// Run the deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 
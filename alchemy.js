const { Network, Alchemy } = require("alchemy-sdk");

const settings = {
  apiKey: "4QoDmZlycUWsehWv0KSde-9CA4QZXxWO", // Your API key
  network: Network.ETH_SEPOLIA, // Sepolia testnet
};

const alchemy = new Alchemy(settings);

// Example function to get the latest block
async function getLatestBlock() {
  try {
    const block = await alchemy.core.getBlock("latest");
    console.log("Latest block:", block);
    return block;
  } catch (error) {
    console.error("Error getting latest block:", error);
    throw error;
  }
}

// Example function to get contract information
async function getContractInfo(contractAddress) {
  try {
    const code = await alchemy.core.getCode(contractAddress);
    console.log("Contract code:", code);
    return code;
  } catch (error) {
    console.error("Error getting contract info:", error);
    throw error;
  }
}

// Example function to get token balances
async function getTokenBalances(address) {
  try {
    const balances = await alchemy.core.getTokenBalances(address);
    console.log("Token balances:", balances);
    return balances;
  } catch (error) {
    console.error("Error getting token balances:", error);
    throw error;
  }
}

module.exports = {
  getLatestBlock,
  getContractInfo,
  getTokenBalances
}; 
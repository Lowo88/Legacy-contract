const { getLatestBlock, getTokenBalances } = require('../alchemy');

async function main() {
  try {
    console.log("Testing Alchemy connection...");
    
    // Get latest block
    const block = await getLatestBlock();
    console.log("Successfully connected to Sepolia!");
    console.log("Latest block number:", block.number);
    
    // Get token balances (replace with your address)
    const address = "0xYourAddressHere";
    const balances = await getTokenBalances(address);
    console.log("Token balances:", balances);
    
  } catch (error) {
    console.error("Error testing Alchemy connection:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 
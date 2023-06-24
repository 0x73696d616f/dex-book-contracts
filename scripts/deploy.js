const hre = require("hardhat");

async function main() {

    const usdcFactory = await hre.ethers.getContractFactory("USDC");
    const usdc = await usdcFactory.deploy();
    await usdc.deployed();

    console.log("usdc contract address:", usdc.address);

    const wethFactory = await hre.ethers.getContractFactory("WETH");
    const weth = await wethFactory.deploy();
    await weth.deployed();

    console.log("weth contract address:", weth.address);

    const dexBookFactory = await hre.ethers.getContractFactory("DexBook");
    const dexBook = await dexBookFactory.deploy(weth.address, usdc.address);
    await dexBook.deployed();

    console.log("dexBook contract address:", dexBook.address);
}

// Call the main function and catch if there is any error
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
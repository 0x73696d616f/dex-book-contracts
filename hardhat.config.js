require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: ".env" });

const APOTHEM_NETWORK_URL = process.env.RPC_URL_APOTHEM;
const APOTHEM_PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  solidity: "0.8.19",
  networks: {
    apothem: {
      url: APOTHEM_NETWORK_URL,
      accounts: [APOTHEM_PRIVATE_KEY],
    },
  },
};

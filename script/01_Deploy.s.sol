// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { DexBook } from "src/DexBook.sol";

import { USDC } from "src/token/USDC.sol";
import { WETH } from "src/token/WETH.sol";

contract Deploy is Script {
    function setUp() public { }

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // deploy test tokens
        USDC usdc = new USDC();
        WETH weth = new WETH();

        // deploy DexBook

        new DexBook(address(weth), address(usdc));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { console } from "@forge-std/console.sol";

import { DexBook } from "src/DexBook.sol";

import { USDC } from "src/token/USDC.sol";
import { WETH } from "src/token/WETH.sol";

contract Deploy is Script {
    address public constant USDC_ADDRESS = 0xB7D27002Ccfe2d7D0056422Be463bD72B2C2eB23;

    function setUp() public { }

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        //vm.startBroadcast();

        (USDC usdc_, WETH weth_, DexBook dexBook_) = _deploy();
        _insertOrders(usdc_, weth_, dexBook_);

        vm.stopBroadcast();
    }

    function _insertOrders(USDC usdc_, WETH eth_, DexBook dexBook_) internal {
        uint256 ethAmount_ = 1e18;
        uint128 price_ = dexBook_.invertPrice(1000 * dexBook_.pricePrecision());
        uint256 usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, price_);

        uint128[] memory prevsNexts_ = new uint128[](1);

        usdc_.approve(address(dexBook_), dexBook_.amountPlusFee(usdcAmount_));
        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        usdc_.approve(address(dexBook_), dexBook_.amountPlusFee(usdcAmount_));
        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        price_ = dexBook_.invertPrice(800 * dexBook_.pricePrecision());
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, price_);

        usdc_.approve(address(dexBook_), dexBook_.amountPlusFee(usdcAmount_));
        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 3e18;
        price_ = 1500 * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        eth_.approve(address(dexBook_), dexBook_.amountPlusFee(ethAmount_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 2e18;
        price_ = 1700 * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        eth_.approve(address(dexBook_), dexBook_.amountPlusFee(ethAmount_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 5e18;
        price_ = 1300 * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        eth_.approve(address(dexBook_), dexBook_.amountPlusFee(ethAmount_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);
    }

    function _deploy() internal returns (USDC usdc_, WETH weth_, DexBook dexBook_) {
        // deploy test tokens
        usdc_ = new USDC();
        weth_ = new WETH();

        // deploy DexBook

        dexBook_ = new DexBook(address(weth_), address(usdc_));
    }
}

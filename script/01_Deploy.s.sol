// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { console } from "@forge-std/console.sol";

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { DexBook } from "src/DexBook.sol";

import { USDC } from "src/token/USDC.sol";
import { WETH } from "src/token/WETH.sol";

import { WBTC } from "src/token/WBTC.sol";

import { USDT } from "src/token/USDT.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        //vm.startBroadcast();

        address usdc_ = address(new USDC());
        address weth_ = address(new WETH());
        address wbtc_ = address(new WBTC());

        uint128[] memory prices_ = _getPrices(1000, 800, 1500, 1700, 1300);

        _deployAndInsertOrders(ERC20(usdc_), ERC20(weth_), prices_);

        _deployAndInsertOrders(ERC20(weth_), ERC20(wbtc_), _getPrices(16, 17, 15, 14, 18));

        prices_ = _getPrices(30_328, 30_100, 31_000, 29_000, 29_500);
        _deployAndInsertOrders(ERC20(usdc_), ERC20(wbtc_), prices_);

        vm.stopBroadcast();
    }

    function _deployAndInsertOrders(ERC20 tokenB_, ERC20 tokenA_, uint128[] memory prices_) internal {
        DexBook dexBook_ = new DexBook(address(tokenA_), address(tokenB_));

        console.log(address(dexBook_), tokenA_.symbol(), tokenB_.symbol());

        tokenA_.approve(address(dexBook_), type(uint256).max);
        tokenB_.approve(address(dexBook_), type(uint256).max);

        uint256 tokenADecimals_ = tokenA_.decimals();

        uint256 ethAmount_ = 1 * 10 ** tokenADecimals_;
        uint128 price_ = dexBook_.invertPrice(prices_[0] * dexBook_.pricePrecision());
        uint256 usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, price_);

        uint128[] memory prevsNexts_ = new uint128[](1);

        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        price_ = dexBook_.invertPrice(prices_[1] * dexBook_.pricePrecision());
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, price_);

        dexBook_.placeBuyLimitOrder(ethAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 3 * 10 ** tokenADecimals_;
        price_ = prices_[2] * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 2 * 10 ** tokenADecimals_;
        price_ = prices_[3] * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);

        ethAmount_ = 5 * 10 ** tokenADecimals_;
        price_ = prices_[4] * dexBook_.pricePrecision();
        usdcAmount_ = dexBook_.tokenAToTokenB(ethAmount_, dexBook_.invertPrice(price_));
        dexBook_.placeSellLimitOrder(usdcAmount_, price_, prevsNexts_, prevsNexts_);

        dexBook_.placeSellMarketOrder(10 ** tokenADecimals_ / 10);
        dexBook_.placeBuyMarketOrder(10 ** dexBook_.tokenBDecimals() / 10);
    }

    function _getPrices(uint128 price1_, uint128 price2_, uint128 price3_, uint128 price4_, uint128 price5_)
        internal
        pure
        returns (uint128[] memory prices_)
    {
        prices_ = new uint128[](5);
        prices_[0] = price1_;
        prices_[1] = price2_;
        prices_[2] = price3_;
        prices_[3] = price4_;
        prices_[4] = price5_;
    }
}

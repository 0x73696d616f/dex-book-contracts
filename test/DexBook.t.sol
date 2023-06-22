// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "@forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { LibLinkedOrders } from "src/lib/LibLinkedOrders.sol";
import { DexBook } from "src/DexBook.sol";

contract USDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DexBookTest is Test {
    DexBook public dexBook;
    ERC20 public eth;
    USDC public usdc;

    address public deployer;
    address public alice;
    address public bob;

    function setUp() external {
        eth = new ERC20("Ether", "ETH");
        usdc = new USDC();
        vm.label(address(eth), "ETH");
        vm.label(address(usdc), "USDC");

        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(deployer);
        dexBook = new DexBook(address(eth), address(usdc));
    }

    function test_DexBook_setup() public {
        assertEq(dexBook.tokenA(), address(eth));
        assertEq(dexBook.tokenB(), address(usdc));
        assertEq(dexBook.tokenADecimals(), 18);
        assertEq(dexBook.tokenBDecimals(), 6);
        assertEq(dexBook.feeRecipient(), deployer);
        assertEq(dexBook.protocolFee(), 10);
    }

    function test_DexBook_placeAndFulfillSellOrders() public {
        uint256 ethAmount_ = 5e18;
        uint128 price_ = 1000 * dexBook.pricePrecision();

        deal(address(eth), alice, _amountPlusFee(ethAmount_));

        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        vm.startPrank(alice);
        eth.approve(address(dexBook), _amountPlusFee(ethAmount_));
        dexBook.placeSellLimitOrder(ethAmount_, price_, prevs_, nexts_);
        vm.stopPrank();

        assertEq(eth.balanceOf(alice), 0);
        assertEq(eth.balanceOf(address(dexBook)), ethAmount_);
        assertEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));

        (LibLinkedOrders.Order[][] memory orders_, uint128[] memory prices_) = dexBook.sellOrdersAndPrices();

        assertEq(orders_[0].length, 1);
        assertEq(orders_[0][0].maker, alice);
        assertEq(orders_[0][0].amount, 5e9);
        assertEq(orders_[0][0].next, 0);
        assertEq(orders_[0][0].prev, 0);

        assertEq(prices_.length, 1);
        assertEq(_invertPrice(prices_[0]), price_);

        // Fill the order

        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, price_);
        deal(address(usdc), bob, _amountPlusFee(usdcAmount_));

        vm.startPrank(bob);
        usdc.approve(address(dexBook), _amountPlusFee(usdcAmount_));
        dexBook.placeBuyMarketOrder(usdcAmount_);
        vm.stopPrank();

        assertEq(usdcAmount_, 5e9);
        assertEq(usdc.balanceOf(alice), usdcAmount_);
        assertEq(usdc.balanceOf(address(dexBook)), 0);
        assertEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));
        assertEq(usdc.balanceOf(bob), 0);

        assertEq(ethAmount_, 5e18);
        assertEq(eth.balanceOf(bob), ethAmount_);
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));
        assertEq(eth.balanceOf(alice), 0);
    }

    function test_DexBook_placeAndFulfillBuyOrders() public {
        uint256 ethAmount_ = 5e18;
        uint128 price_ = 1000 * dexBook.pricePrecision();

        deal(address(usdc), bob, _amountPlusFee(_ethToUsdc(ethAmount_, price_)));

        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        vm.startPrank(bob);
        usdc.approve(address(dexBook), _amountPlusFee(_ethToUsdc(ethAmount_, price_)));
        dexBook.placeBuyLimitOrder(ethAmount_, price_, prevs_, nexts_);
        vm.stopPrank();

        assertEq(usdc.balanceOf(bob), 0);
        assertEq(usdc.balanceOf(address(dexBook)), _ethToUsdc(ethAmount_, price_));
        assertEq(usdc.balanceOf(deployer), _feeAmount(_ethToUsdc(ethAmount_, price_)));

        (LibLinkedOrders.Order[][] memory orders_, uint128[] memory prices_) = dexBook.buyOrdersAndPrices();

        assertEq(orders_[0].length, 1);
        assertEq(orders_[0][0].maker, bob);
        assertEq(orders_[0][0].amount, ethAmount_);
        assertEq(orders_[0][0].next, 0);
        assertEq(orders_[0][0].prev, 0);

        assertEq(prices_.length, 1);
        assertEq(prices_[0], price_);
    }

    function _amountPlusFee(uint256 amount) internal view returns (uint256) {
        return amount + _feeAmount(amount);
    }

    function _feeAmount(uint256 amount) internal view returns (uint256) {
        return amount * dexBook.protocolFee() / 10_000;
    }

    function _ethToUsdc(uint256 amount_, uint128 price_) internal pure returns (uint256) {
        return amount_ * price_ * 1e6 / 1e18 / 1e18;
    }

    function _usdcToEth(uint256 amount_, uint128 price_) internal pure returns (uint256) {
        return amount_ * 1e18 * 1e18 / price_ / 1e6;
    }

    function _invertPrice(uint128 price_) internal pure returns (uint128) {
        return 1e36 / price_;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "@forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { LibPriceBrackets } from "src/lib/LibPriceBrackets.sol";

contract LibPriceBracketsTest is Test {
    using LibPriceBrackets for LibPriceBrackets.PriceBrackets;

    LibPriceBrackets.PriceBrackets public linkedPriceBrackets;
    ERC20 public token;

    address public firstMaker = makeAddr("firstMaker");
    address public secondMaker = makeAddr("secondMaker");
    address public thirdMaker = makeAddr("thirdMaker");
    address public fourthMaker = makeAddr("fourthMaker");
    address public fifthMaker = makeAddr("fifthMaker");

    function setUp() public {
        token = new ERC20("Test Token", "TEST");
        deal(address(token), address(this), type(uint256).max);
    }

    function test_LibPriceBrackets_insertOrders() public {
        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        this.insertOrder(100, firstMaker, 200, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 200);

        this.insertOrder(100, secondMaker, 300, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 500);
    }

    function insertOrder(
        uint128 price_,
        address maker_,
        uint256 amount_,
        uint128[] calldata prevs_,
        uint128[] calldata nexts_
    ) external returns (uint48 orderId_) {
        orderId_ = linkedPriceBrackets.insertOrder(price_, maker_, amount_, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[price_].linkedOrders.orders[orderId_].maker, maker_);
        assertEq(linkedPriceBrackets.priceBrackets[price_].linkedOrders.orders[orderId_].amount, amount_);
    }
}

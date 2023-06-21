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
        assertEq(linkedPriceBrackets.lowestPrice, 100);
        assertEq(linkedPriceBrackets.highestPrice, 100);

        this.insertOrder(100, secondMaker, 300, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 500);
        assertEq(linkedPriceBrackets.lowestPrice, 100);
        assertEq(linkedPriceBrackets.highestPrice, 100);

        nexts_[0] = 100;
        this.insertOrder(50, thirdMaker, 400, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 500);
        assertEq(linkedPriceBrackets.lowestPrice, 50);
        assertEq(linkedPriceBrackets.highestPrice, 100);

        prevs_[0] = 100;
        nexts_[0] = 0;
        this.insertOrder(110, fourthMaker, 600, prevs_, nexts_);
        assertEq(linkedPriceBrackets.priceBrackets[110].accumulatedAmount, 600);
        assertEq(linkedPriceBrackets.lowestPrice, 50);
        assertEq(linkedPriceBrackets.highestPrice, 110);
    }

    function test_LibPriceBrackets_removeOrders() public {
        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        this.insertOrder(100, firstMaker, 200, prevs_, nexts_);
        this.insertOrder(100, secondMaker, 300, prevs_, nexts_);
        this.insertOrder(50, thirdMaker, 400, prevs_, nexts_);
        this.insertOrder(110, fourthMaker, 600, prevs_, nexts_);

        linkedPriceBrackets.removeOrder(100, 1, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 300);
        assertEq(linkedPriceBrackets.lowestPrice, 50);
        assertEq(linkedPriceBrackets.highestPrice, 110);

        linkedPriceBrackets.removeOrder(100, 2, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[100].accumulatedAmount, 0);
        assertEq(linkedPriceBrackets.lowestPrice, 50);
        assertEq(linkedPriceBrackets.highestPrice, 110);

        linkedPriceBrackets.removeOrder(50, 1, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[50].accumulatedAmount, 0);
        assertEq(linkedPriceBrackets.lowestPrice, 110);
        assertEq(linkedPriceBrackets.highestPrice, 110);

        linkedPriceBrackets.removeOrder(110, 1, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[110].accumulatedAmount, 0);
        assertEq(linkedPriceBrackets.lowestPrice, 0);
        assertEq(linkedPriceBrackets.highestPrice, 0);

        this.insertOrder(120, firstMaker, 200, prevs_, nexts_);

        linkedPriceBrackets.removeOrder(120, 1, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[120].accumulatedAmount, 0);
        assertEq(linkedPriceBrackets.lowestPrice, 0);
        assertEq(linkedPriceBrackets.highestPrice, 0);

        this.insertOrder(120, firstMaker, 200, prevs_, nexts_);
        this.insertOrder(120, secondMaker, 300, prevs_, nexts_);
        this.insertOrder(120, thirdMaker, 400, prevs_, nexts_);

        linkedPriceBrackets.removeOrder(120, 1, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[120].accumulatedAmount, 700);
        assertEq(linkedPriceBrackets.lowestPrice, 120);
        assertEq(linkedPriceBrackets.highestPrice, 120);

        linkedPriceBrackets.removeOrder(120, 2, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[120].accumulatedAmount, 400);
        assertEq(linkedPriceBrackets.lowestPrice, 120);
        assertEq(linkedPriceBrackets.highestPrice, 120);

        linkedPriceBrackets.removeOrder(120, 3, address(token));
        assertEq(linkedPriceBrackets.priceBrackets[120].accumulatedAmount, 0);
        assertEq(linkedPriceBrackets.lowestPrice, 0);
        assertEq(linkedPriceBrackets.highestPrice, 0);
    }

    function test_LibPriceBrackets_findClosestPrev_findClosestNext() public {
        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        this.insertOrder(100, firstMaker, 200, prevs_, nexts_);
        this.insertOrder(100, secondMaker, 300, prevs_, nexts_);
        this.insertOrder(50, thirdMaker, 400, prevs_, nexts_);
        this.insertOrder(110, fourthMaker, 600, prevs_, nexts_);

        assertEq(this.findClosestPrev(prevs_, 50), 0);
        assertEq(this.findClosestPrev(prevs_, 100), 50);
        assertEq(this.findClosestPrev(prevs_, 110), 100);

        assertEq(this.findClosestNext(nexts_, 50), 100);
        assertEq(this.findClosestNext(nexts_, 100), 110);
        assertEq(this.findClosestNext(nexts_, 110), 0);

        prevs_[0] = 50;
        assertEq(this.findClosestPrev(prevs_, 100), 50);
        assertEq(this.findClosestPrev(prevs_, 110), 100);

        nexts_[0] = 110;
        assertEq(this.findClosestNext(nexts_, 50), 100);
        assertEq(this.findClosestNext(nexts_, 100), 110);

        nexts_[0] = 0;
        prevs_ = new uint128[](3);
        prevs_[0] = 49;
        prevs_[1] = 48;
        prevs_[2] = 0;

        assertEq(this.findClosestPrev(prevs_, 50), 0);
        assertEq(this.findClosestPrev(prevs_, 100), 50);
        assertEq(this.findClosestPrev(prevs_, 110), 100);

        nexts_ = new uint128[](3);
        nexts_[0] = 51;
        nexts_[1] = 52;
        nexts_[2] = 0;

        assertEq(this.findClosestNext(nexts_, 50), 100);
        assertEq(this.findClosestNext(nexts_, 100), 110);
        assertEq(this.findClosestNext(nexts_, 110), 0);

        prevs_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_ = new uint128[](1);
        nexts_[0] = 0;

        this.insertOrder(101, firstMaker, 200, prevs_, nexts_);
        this.insertOrder(102, secondMaker, 300, prevs_, nexts_);
        this.insertOrder(103, thirdMaker, 400, prevs_, nexts_);
        this.insertOrder(104, fourthMaker, 600, prevs_, nexts_);
        this.insertOrder(105, fifthMaker, 600, prevs_, nexts_);

        assertEq(this.findClosestPrev(prevs_, 110), 105);
        assertEq(this.findClosestPrev(prevs_, 105), 104);
        assertEq(this.findClosestPrev(prevs_, 104), 103);
        assertEq(this.findClosestPrev(prevs_, 103), 102);
        assertEq(this.findClosestPrev(prevs_, 102), 101);
        assertEq(this.findClosestPrev(prevs_, 101), 100);
        assertEq(this.findClosestPrev(prevs_, 100), 50);
        assertEq(this.findClosestPrev(prevs_, 50), 0);

        assertEq(this.findClosestNext(nexts_, 50), 100);
        assertEq(this.findClosestNext(nexts_, 100), 101);
        assertEq(this.findClosestNext(nexts_, 101), 102);
        assertEq(this.findClosestNext(nexts_, 102), 103);
        assertEq(this.findClosestNext(nexts_, 103), 104);
        assertEq(this.findClosestNext(nexts_, 104), 105);
        assertEq(this.findClosestNext(nexts_, 105), 110);
        assertEq(this.findClosestNext(nexts_, 110), 0);
    }

    function test_LibPriceBrackets_RemoveOrdersUntilTarget() public { }

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

    function findClosestPrev(uint128[] calldata prevs_, uint128 price_) external view returns (uint128) {
        return linkedPriceBrackets._findClosestPrev(prevs_, price_);
    }

    function findClosestNext(uint128[] calldata nexts_, uint128 price_) external view returns (uint128) {
        return linkedPriceBrackets._findClosestNext(nexts_, price_);
    }
}

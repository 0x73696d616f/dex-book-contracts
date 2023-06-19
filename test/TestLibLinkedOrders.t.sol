// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "@forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { LibLinkedOrders } from "src/lib/LibLinkedOrders.sol";

contract LibLinkedOrdersTest is Test {
    using LibLinkedOrders for LibLinkedOrders.LinkedOrders;

    LibLinkedOrders.LinkedOrders public linkedOrders;
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

    function test_LibLinkedOrders_InsertRemoveOrders() public {
        _insertOrders();
        linkedOrders.remove(1, address(token));
        assertEq(token.balanceOf(firstMaker), 1);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 2);
        assertEq(linkedOrders.tail, 5);

        _assertDeletedOrder(1);

        assertEq(linkedOrders.orders[2].maker, secondMaker);
        assertEq(linkedOrders.orders[2].prev, 0);
        assertEq(linkedOrders.orders[2].next, 3);
        assertEq(linkedOrders.orders[2].amount, 2);

        assertEq(linkedOrders.orders[3].maker, thirdMaker);
        assertEq(linkedOrders.orders[3].prev, 2);
        assertEq(linkedOrders.orders[3].next, 4);
        assertEq(linkedOrders.orders[3].amount, 3);

        assertEq(linkedOrders.orders[4].maker, fourthMaker);
        assertEq(linkedOrders.orders[4].prev, 3);
        assertEq(linkedOrders.orders[4].next, 5);
        assertEq(linkedOrders.orders[4].amount, 4);

        assertEq(linkedOrders.orders[5].maker, fifthMaker);
        assertEq(linkedOrders.orders[5].prev, 4);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 5);

        linkedOrders.remove(4, address(token));
        assertEq(token.balanceOf(fourthMaker), 4);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 2);
        assertEq(linkedOrders.tail, 5);

        assertEq(linkedOrders.orders[2].maker, secondMaker);
        assertEq(linkedOrders.orders[2].prev, 0);
        assertEq(linkedOrders.orders[2].next, 3);
        assertEq(linkedOrders.orders[2].amount, 2);

        assertEq(linkedOrders.orders[3].maker, thirdMaker);
        assertEq(linkedOrders.orders[3].prev, 2);
        assertEq(linkedOrders.orders[3].next, 5);
        assertEq(linkedOrders.orders[3].amount, 3);

        _assertDeletedOrder(4);

        assertEq(linkedOrders.orders[5].maker, fifthMaker);
        assertEq(linkedOrders.orders[5].prev, 3);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 5);

        linkedOrders.remove(5, address(token));
        assertEq(token.balanceOf(fifthMaker), 5);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 2);
        assertEq(linkedOrders.tail, 3);

        assertEq(linkedOrders.orders[2].maker, secondMaker);
        assertEq(linkedOrders.orders[2].prev, 0);
        assertEq(linkedOrders.orders[2].next, 3);
        assertEq(linkedOrders.orders[2].amount, 2);

        assertEq(linkedOrders.orders[3].maker, thirdMaker);
        assertEq(linkedOrders.orders[3].prev, 2);
        assertEq(linkedOrders.orders[3].next, 0);
        assertEq(linkedOrders.orders[3].amount, 3);

        assertEq(linkedOrders.orders[5].maker, address(0));
        assertEq(linkedOrders.orders[5].prev, 0);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 0);

        linkedOrders.remove(2, address(token));
        assertEq(token.balanceOf(secondMaker), 2);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 3);
        assertEq(linkedOrders.tail, 3);

        _assertDeletedOrder(2);

        assertEq(linkedOrders.orders[3].maker, thirdMaker);
        assertEq(linkedOrders.orders[3].prev, 0);
        assertEq(linkedOrders.orders[3].next, 0);
        assertEq(linkedOrders.orders[3].amount, 3);

        linkedOrders.remove(3, address(token));

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 0);
        assertEq(linkedOrders.tail, 0);

        _assertDeletedOrder(3);

        linkedOrders.insert(firstMaker, 1);

        assertEq(linkedOrders.length, 6);
        assertEq(linkedOrders.head, 6);
        assertEq(linkedOrders.tail, 6);

        assertEq(linkedOrders.orders[6].maker, firstMaker);
        assertEq(linkedOrders.orders[6].prev, 0);
        assertEq(linkedOrders.orders[6].next, 0);
        assertEq(linkedOrders.orders[6].amount, 1);

        linkedOrders.insert(secondMaker, 2);

        assertEq(linkedOrders.length, 7);
        assertEq(linkedOrders.head, 6);
        assertEq(linkedOrders.tail, 7);

        assertEq(linkedOrders.orders[6].maker, firstMaker);
        assertEq(linkedOrders.orders[6].prev, 0);
        assertEq(linkedOrders.orders[6].next, 7);
        assertEq(linkedOrders.orders[6].amount, 1);

        assertEq(linkedOrders.orders[7].maker, secondMaker);
        assertEq(linkedOrders.orders[7].prev, 6);
        assertEq(linkedOrders.orders[7].next, 0);
        assertEq(linkedOrders.orders[7].amount, 2);

        linkedOrders.insert(thirdMaker, 3);

        assertEq(linkedOrders.length, 8);
        assertEq(linkedOrders.head, 6);
        assertEq(linkedOrders.tail, 8);

        assertEq(linkedOrders.orders[6].maker, firstMaker);
        assertEq(linkedOrders.orders[6].prev, 0);
        assertEq(linkedOrders.orders[6].next, 7);
        assertEq(linkedOrders.orders[6].amount, 1);

        assertEq(linkedOrders.orders[7].maker, secondMaker);
        assertEq(linkedOrders.orders[7].prev, 6);
        assertEq(linkedOrders.orders[7].next, 8);
        assertEq(linkedOrders.orders[7].amount, 2);

        assertEq(linkedOrders.orders[8].maker, thirdMaker);
        assertEq(linkedOrders.orders[8].prev, 7);
        assertEq(linkedOrders.orders[8].next, 0);
        assertEq(linkedOrders.orders[8].amount, 3);

        linkedOrders.remove(7, address(token));
        assertEq(token.balanceOf(secondMaker), 4);

        assertEq(linkedOrders.length, 8);
        assertEq(linkedOrders.head, 6);
        assertEq(linkedOrders.tail, 8);

        assertEq(linkedOrders.orders[6].maker, address(firstMaker));
        assertEq(linkedOrders.orders[6].prev, 0);
        assertEq(linkedOrders.orders[6].next, 8);
        assertEq(linkedOrders.orders[6].amount, 1);

        _assertDeletedOrder(7);

        assertEq(linkedOrders.orders[8].maker, thirdMaker);
        assertEq(linkedOrders.orders[8].prev, 6);
        assertEq(linkedOrders.orders[8].next, 0);
        assertEq(linkedOrders.orders[8].amount, 3);

        linkedOrders.remove(6, address(token));
        assertEq(token.balanceOf(firstMaker), 2);

        assertEq(linkedOrders.length, 8);
        assertEq(linkedOrders.head, 8);
        assertEq(linkedOrders.tail, 8);

        _assertDeletedOrder(6);
        _assertDeletedOrder(7);

        assertEq(linkedOrders.orders[8].maker, thirdMaker);
        assertEq(linkedOrders.orders[8].prev, 0);
        assertEq(linkedOrders.orders[8].next, 0);
        assertEq(linkedOrders.orders[8].amount, 3);

        linkedOrders.remove(8, address(token));

        assertEq(linkedOrders.length, 8);
        assertEq(linkedOrders.head, 0);
        assertEq(linkedOrders.tail, 0);

        _assertDeletedOrder(8);
    }

    function test_LibLinkedOrders_RemoveUntilTarget() public {
        _insertOrders();

        // test some orders deleted, then partial fulfillment of 4th //

        // 1 + 2 + 3 + 4 = 10
        linkedOrders.removeUntilTarget(7, address(token));
        assertEq(token.balanceOf(firstMaker), 1);
        assertEq(token.balanceOf(secondMaker), 2);
        assertEq(token.balanceOf(thirdMaker), 3);
        assertEq(token.balanceOf(fourthMaker), 1);
        assertEq(token.balanceOf(fifthMaker), 0);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 4);
        assertEq(linkedOrders.tail, 5);

        // 1, 2 and 3 are deleted
        for (uint48 i_ = 1; i_ < 4; i_++) {
            _assertDeletedOrder(i_);
        }
        // 4 and 5 are left. 4 only has 3 left
        assertEq(linkedOrders.orders[4].maker, fourthMaker);
        assertEq(linkedOrders.orders[4].prev, 0);
        assertEq(linkedOrders.orders[4].next, 5);
        assertEq(linkedOrders.orders[4].amount, 3);

        assertEq(linkedOrders.orders[5].maker, fifthMaker);
        assertEq(linkedOrders.orders[5].prev, 4);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 5);

        // test no orders deleted, partial fulfillment //

        linkedOrders.removeUntilTarget(1, address(token));
        assertEq(token.balanceOf(firstMaker), 1);
        assertEq(token.balanceOf(secondMaker), 2);
        assertEq(token.balanceOf(thirdMaker), 3);
        assertEq(token.balanceOf(fourthMaker), 2);
        assertEq(token.balanceOf(fifthMaker), 0);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 4);
        assertEq(linkedOrders.tail, 5);

        // 4 and 5 are left. 4 only has 2 left
        assertEq(linkedOrders.orders[4].maker, fourthMaker);
        assertEq(linkedOrders.orders[4].prev, 0);
        assertEq(linkedOrders.orders[4].next, 5);
        assertEq(linkedOrders.orders[4].amount, 2);

        assertEq(linkedOrders.orders[5].maker, fifthMaker);
        assertEq(linkedOrders.orders[5].prev, 4);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 5);

        // test all orders deleted

        assertEq(linkedOrders.removeUntilTarget(10, address(token)), 7);
        assertEq(token.balanceOf(firstMaker), 1);
        assertEq(token.balanceOf(secondMaker), 2);
        assertEq(token.balanceOf(thirdMaker), 3);
        assertEq(token.balanceOf(fourthMaker), 4);
        assertEq(token.balanceOf(fifthMaker), 5);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 0);
        assertEq(linkedOrders.tail, 0);

        for (uint48 i_ = 1; i_ < 6; i_++) {
            _assertDeletedOrder(i_);
        }
    }

    function _insertOrders() internal {
        linkedOrders.insert(firstMaker, 1);
        linkedOrders.insert(secondMaker, 2);
        linkedOrders.insert(thirdMaker, 3);
        linkedOrders.insert(fourthMaker, 4);
        linkedOrders.insert(fifthMaker, 5);

        assertEq(linkedOrders.length, 5);
        assertEq(linkedOrders.head, 1);
        assertEq(linkedOrders.tail, 5);

        assertEq(linkedOrders.orders[1].maker, firstMaker);
        assertEq(linkedOrders.orders[1].prev, 0);
        assertEq(linkedOrders.orders[1].next, 2);
        assertEq(linkedOrders.orders[1].amount, 1);

        assertEq(linkedOrders.orders[2].maker, secondMaker);
        assertEq(linkedOrders.orders[2].prev, 1);
        assertEq(linkedOrders.orders[2].next, 3);
        assertEq(linkedOrders.orders[2].amount, 2);

        assertEq(linkedOrders.orders[3].maker, thirdMaker);
        assertEq(linkedOrders.orders[3].prev, 2);
        assertEq(linkedOrders.orders[3].next, 4);
        assertEq(linkedOrders.orders[3].amount, 3);

        assertEq(linkedOrders.orders[4].maker, fourthMaker);
        assertEq(linkedOrders.orders[4].prev, 3);
        assertEq(linkedOrders.orders[4].next, 5);
        assertEq(linkedOrders.orders[4].amount, 4);

        assertEq(linkedOrders.orders[5].maker, fifthMaker);
        assertEq(linkedOrders.orders[5].prev, 4);
        assertEq(linkedOrders.orders[5].next, 0);
        assertEq(linkedOrders.orders[5].amount, 5);
    }

    function _assertDeletedOrder(uint48 orderId_) internal {
        assertEq(linkedOrders.orders[orderId_].maker, address(0));
        assertEq(linkedOrders.orders[orderId_].prev, 0);
        assertEq(linkedOrders.orders[orderId_].next, 0);
        assertEq(linkedOrders.orders[orderId_].amount, 0);
    }
}

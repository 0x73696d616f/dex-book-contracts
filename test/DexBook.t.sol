// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "@forge-std/Test.sol";

import { DexBook } from "src/DexBook.sol";

contract DexBookTest is Test {
    DexBook public dexBook;

    function setUp() external {
        dexBook = new DexBook(address(0), address(0));
    }
}

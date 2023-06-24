// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract FaucetERC20 is ERC20 {
    constructor(string memory symbol_, string memory name_) ERC20(symbol_, name_) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function faucet() external {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}

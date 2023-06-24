// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { FaucetERC20 } from "./FaucetERC20.sol";

contract USDC is FaucetERC20 {
    constructor() FaucetERC20("USD Coin", "USDC") { }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

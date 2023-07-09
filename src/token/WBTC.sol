// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { FaucetERC20 } from "./FaucetERC20.sol";

contract WBTC is FaucetERC20 {
    constructor() FaucetERC20("Wrapped BTC", "WBTC") { }
}

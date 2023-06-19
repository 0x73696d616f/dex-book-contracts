// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { LibPriceBrackets } from "./lib/LibPriceBrackets.sol";

contract DexBook {
    using LibPriceBrackets for LibPriceBrackets.PriceBrackets;

    uint256 internal constant PRECISION = 10 ** 18;

    address internal immutable _tokenA;
    address internal immutable _tokenB;

    LibPriceBrackets.PriceBrackets internal _buyOrders;
    LibPriceBrackets.PriceBrackets internal _sellOrders;

    constructor(address tokenA_, address tokenB_) {
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    function placeBuyLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
    {
        ERC20(_tokenB).transferFrom(msg.sender, address(this), amount_);
        _buyOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    function placeSellLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
    {
        ERC20(_tokenA).transferFrom(msg.sender, address(this), amount_);
        _sellOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    function placeBuyMarketOrder(uint256 amount_) external {
        uint256 cost_;
        (amount_, cost_) = _buyOrders.removeOrdersUntilTarget(amount_);
        ERC20(_tokenB).transferFrom(msg.sender, address(this), cost_);
        ERC20(_tokenA).transfer(msg.sender, amount_);
    }

    function placeSellMarketOrder(uint256 amount_) external {
        uint256 cost_;
        (amount_, cost_) = _sellOrders.removeOrdersUntilTarget(amount_);
        ERC20(_tokenA).transferFrom(msg.sender, address(this), amount_);
        ERC20(_tokenB).transfer(msg.sender, cost_);
    }
}

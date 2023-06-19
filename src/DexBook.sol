// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { LibPriceBrackets } from "./lib/LibPriceBrackets.sol";

contract DexBook {
    using LibPriceBrackets for LibPriceBrackets.PriceBrackets;

    uint256 internal constant PRECISION = 10 ** 18;

    address internal immutable _tokenA;
    address internal immutable _tokenB;

    uint256 internal immutable _tokenADecimals;
    uint256 internal immutable _tokenBDecimals;

    LibPriceBrackets.PriceBrackets internal _buyOrders;
    LibPriceBrackets.PriceBrackets internal _sellOrders;

    constructor(address tokenA_, address tokenB_) {
        _tokenA = tokenA_;
        _tokenB = tokenB_;
        _tokenADecimals = ERC20(tokenA_).decimals();
        _tokenBDecimals = ERC20(tokenB_).decimals();
    }

    function placeBuyLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
    {
        ERC20(_tokenB).transferFrom(
            msg.sender, address(this), amount_ * 10 ** _tokenBDecimals / 10 ** _tokenADecimals * price_ / PRECISION
        );
        _buyOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    function placeSellLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
    {
        ERC20(_tokenA).transferFrom(
            msg.sender, address(this), amount_ * 10 ** _tokenADecimals / 10 ** _tokenBDecimals * price_ / PRECISION
        );
        _sellOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    function placeBuyMarketOrder(uint256 amount_) external {
        ERC20(_tokenB).transferFrom(msg.sender, address(this), amount_);

        (uint256 availableAmount_, uint256 cost_) = _sellOrders.removeOrdersUntilTarget(amount_, _tokenB);

        if (availableAmount_ != amount_) ERC20(_tokenB).transfer(msg.sender, amount_ - availableAmount_);
        ERC20(_tokenA).transfer(msg.sender, cost_ * 10 ** _tokenADecimals / 10 ** _tokenBDecimals / PRECISION);
    }

    /**
     *
     * @notice Buys tokenB with tokenA at the best available price
     * @param amount_ Amount of tokenA used to buy tokenB
     */
    function placeSellMarketOrder(uint256 amount_) external {
        ERC20(_tokenA).transferFrom(msg.sender, address(this), amount_);

        (uint256 availableAmount_, uint256 cost_) = _buyOrders.removeOrdersUntilTarget(amount_, _tokenA);

        if (availableAmount_ != amount_) ERC20(_tokenA).transfer(msg.sender, amount_ - availableAmount_);
        ERC20(_tokenB).transfer(msg.sender, cost_ * 10 ** _tokenBDecimals / 10 ** _tokenADecimals / PRECISION);
    }
}

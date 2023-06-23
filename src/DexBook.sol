// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { LibLinkedOrders } from "./lib/LibLinkedOrders.sol";
import { LibPriceBrackets } from "./lib/LibPriceBrackets.sol";

contract DexBook {
    using LibPriceBrackets for LibPriceBrackets.PriceBrackets;

    uint128 internal constant PRICE_PRECISION = 10 ** 18;
    uint256 internal constant BASIS_POINT = 10 ** 4;

    uint256 internal constant _protocolFee = 10; // 10 basis points or 0.1%

    uint256 internal immutable _tokenADecimals;
    uint256 internal immutable _tokenBDecimals;

    address internal immutable _tokenA;
    address internal immutable _tokenB;
    address internal immutable _feeRecipient;

    LibPriceBrackets.PriceBrackets internal _buyOrders;
    LibPriceBrackets.PriceBrackets internal _sellOrders;

    constructor(address tokenA_, address tokenB_) {
        _tokenA = tokenA_;
        _tokenB = tokenB_;
        _tokenADecimals = ERC20(tokenA_).decimals();
        _tokenBDecimals = ERC20(tokenB_).decimals();
        _feeRecipient = msg.sender;
    }

    /**
     *
     * @param amount_ tokenA amount to buy
     * @param price_ tokenB/tokenA, not considering decimals
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function placeBuyLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
        returns (uint48)
    {
        uint256 tokenBamount_ = tokenAToTokenB(amount_, price_);
        ERC20(_tokenB).transferFrom(msg.sender, address(this), tokenBamount_);
        ERC20(_tokenB).transferFrom(msg.sender, _feeRecipient, tokenBamount_ * _protocolFee / BASIS_POINT);
        return _buyOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    /**
     * @param amount_ tokenB amount to sell
     * @param price_ tokenA/tokenB, not considering decimals
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function placeSellLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
        returns (uint48)
    {
        uint256 tokenAamount_ = tokenBToTokenA(amount_, price_);
        ERC20(_tokenA).transferFrom(msg.sender, address(this), tokenAamount_);
        ERC20(_tokenA).transferFrom(msg.sender, _feeRecipient, tokenAamount_ * _protocolFee / BASIS_POINT);
        return _sellOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
    }

    function placeBuyMarketOrder(uint256 tokenBamount_) external {
        ERC20(_tokenB).transferFrom(msg.sender, address(this), tokenBamount_);
        ERC20(_tokenB).transferFrom(msg.sender, _feeRecipient, tokenBamount_ * _protocolFee / BASIS_POINT);

        (uint256 tokenBAvailable_, uint256 tokenAAmount_) = _sellOrders.removeOrdersUntilTarget(tokenBamount_, _tokenB);

        if (tokenBAvailable_ != tokenBamount_) ERC20(_tokenB).transfer(msg.sender, tokenBamount_ - tokenBAvailable_);
        ERC20(_tokenA).transfer(msg.sender, tokenBToTokenADecimals(tokenAAmount_) / PRICE_PRECISION);
    }

    /**
     *
     * @notice Buys tokenB with tokenA at the best available price
     * @param tokenAAmount_ Amount of tokenA used to buy tokenB
     */
    function placeSellMarketOrder(uint256 tokenAAmount_) external {
        ERC20(_tokenA).transferFrom(msg.sender, address(this), tokenAAmount_);
        ERC20(_tokenA).transferFrom(msg.sender, _feeRecipient, tokenAAmount_ * _protocolFee / BASIS_POINT);

        (uint256 tokenAAvailable_, uint256 tokenBAmount_) = _buyOrders.removeOrdersUntilTarget(tokenAAmount_, _tokenA);

        if (tokenAAvailable_ != tokenAAmount_) ERC20(_tokenA).transfer(msg.sender, tokenAAmount_ - tokenAAvailable_);
        ERC20(_tokenB).transfer(msg.sender, tokenAToTokenBDecimals(tokenBAmount_) / PRICE_PRECISION);
    }

    function tokenAToTokenB(uint256 amount_, uint256 price_) public view returns (uint256) {
        return amount_ * PRICE_PRECISION * 10 ** _tokenBDecimals / 10 ** _tokenADecimals / price_;
    }

    function tokenBToTokenA(uint256 amount_, uint256 price_) public view returns (uint256) {
        return amount_ * PRICE_PRECISION * 10 ** _tokenADecimals / 10 ** _tokenBDecimals / price_;
    }

    function tokenAToTokenBDecimals(uint256 amount_) public view returns (uint256) {
        return amount_ * 10 ** _tokenBDecimals / 10 ** _tokenADecimals;
    }

    function tokenBToTokenADecimals(uint256 amount_) public view returns (uint256) {
        return amount_ * 10 ** _tokenADecimals / 10 ** _tokenBDecimals;
    }

    function pricePrecision() external pure returns (uint128) {
        return PRICE_PRECISION;
    }

    function tokenA() external view returns (address) {
        return _tokenA;
    }

    function tokenB() external view returns (address) {
        return _tokenB;
    }

    function tokenADecimals() external view returns (uint256) {
        return _tokenADecimals;
    }

    function tokenBDecimals() external view returns (uint256) {
        return _tokenBDecimals;
    }

    function protocolFee() external pure returns (uint256) {
        return _protocolFee;
    }

    function feeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    function sellOrdersPrices() external view returns (uint128[] memory prices_) {
        return _sellOrders.getPrices();
    }

    function buyOrdersPrices() external view returns (uint128[] memory prices_) {
        return _buyOrders.getPrices();
    }

    function sellOrdersAtPrice(uint128 price_) external view returns (LibLinkedOrders.Order[] memory orders_) {
        return _sellOrders.getOrdersAtPrice(price_);
    }

    function buyOrdersAtPrice(uint128 price_) external view returns (LibLinkedOrders.Order[] memory orders_) {
        return _buyOrders.getOrdersAtPrice(price_);
    }

    function sellOrderAtPrice(uint128 price_, uint48 orderId_)
        external
        view
        returns (LibLinkedOrders.Order memory order_)
    {
        return _sellOrders.getOrderAtPrice(price_, orderId_);
    }

    function buyOrderAtPrice(uint128 price_, uint48 orderId_)
        external
        view
        returns (LibLinkedOrders.Order memory order_)
    {
        return _buyOrders.getOrderAtPrice(price_, orderId_);
    }

    function sellOrdersAndPrices() external view returns (LibPriceBrackets.OrdersByPrice[] memory orders_) {
        return _sellOrders.getOrdersAndPrices();
    }

    function buyOrdersAndPrices() external view returns (LibPriceBrackets.OrdersByPrice[] memory orders_) {
        return _buyOrders.getOrdersAndPrices();
    }

    function invertPrice(uint128 price_) external pure returns (uint128) {
        return PRICE_PRECISION ** 2 / price_;
    }
}

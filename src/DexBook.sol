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

    event BuyLimitOrderPlaced(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);
    event SellLimitOrderPlaced(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);

    event BuyLimitOrderCancelled(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);
    event SellLimitOrderCancelled(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);

    event BuyLimitOrderFilled(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);
    event SellLimitOrderFilled(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);

    event BuyLimitOrderModified(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);
    event SellLimitOrderModified(uint48 indexed orderId, uint128 indexed price, address indexed maker, uint256 amount);

    event BuyMarketOrderFilled(uint256 indexed price, address indexed maker, uint256 amount);
    event SellMarketOrderFilled(uint256 indexed price, address indexed maker, uint256 amount);

    error SameAmountError(uint256 amount);
    error OnlyMakerError(address maker);
    error SamePriceError(uint128 price);

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
     * @param price_ tokenB/tokenA, not considering decimals, with `PRICE_PRECISION`
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function placeBuyLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
        returns (uint48 orderId_)
    {
        uint256 tokenBamount_ = tokenAToTokenB(amount_, price_);
        ERC20(_tokenB).transferFrom(msg.sender, address(this), tokenBamount_);
        ERC20(_tokenB).transferFrom(msg.sender, _feeRecipient, tokenBamount_ * _protocolFee / BASIS_POINT);
        orderId_ = _buyOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
        emit BuyLimitOrderPlaced(orderId_, price_, msg.sender, amount_);
    }

    /**
     * @param amount_ tokenB amount to sell
     * @param price_ tokenA/tokenB, not considering decimals, with `PRICE_PRECISION`
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function placeSellLimitOrder(uint256 amount_, uint128 price_, uint128[] calldata prevs_, uint128[] calldata nexts_)
        external
        returns (uint48 orderId_)
    {
        uint256 tokenAamount_ = tokenBToTokenA(amount_, price_);
        ERC20(_tokenA).transferFrom(msg.sender, address(this), tokenAamount_);
        ERC20(_tokenA).transferFrom(msg.sender, _feeRecipient, tokenAamount_ * _protocolFee / BASIS_POINT);
        orderId_ = _sellOrders.insertOrder(price_, msg.sender, amount_, prevs_, nexts_);
        emit SellLimitOrderPlaced(orderId_, price_, msg.sender, amount_);
    }

    /**
     * @notice buys tokenA with tokenB at the best available price
     * @param tokenBamount_ amount of tokenB used to buy tokenA
     */
    function placeBuyMarketOrder(uint256 tokenBamount_) external {
        ERC20(_tokenB).transferFrom(msg.sender, address(this), tokenBamount_);
        ERC20(_tokenB).transferFrom(msg.sender, _feeRecipient, tokenBamount_ * _protocolFee / BASIS_POINT);

        (uint256 tokenBAvailable_, uint256 tokenAamount_) =
            _sellOrders.removeOrdersUntilTarget(tokenBamount_, _fulfillSellLimitOrder);

        if (tokenBAvailable_ != tokenBamount_) ERC20(_tokenB).transfer(msg.sender, tokenBamount_ - tokenBAvailable_);
        ERC20(_tokenA).transfer(msg.sender, tokenBToTokenADecimals(tokenAamount_) / PRICE_PRECISION);
        emit BuyMarketOrderFilled(tokenBAvailable_ * PRICE_PRECISION / tokenAamount_, msg.sender, tokenAamount_);
    }

    /**
     * @notice buys tokenB with tokenA at the best available price
     * @param tokenAamount_ amount of tokenA used to buy tokenB
     */
    function placeSellMarketOrder(uint256 tokenAamount_) external {
        ERC20(_tokenA).transferFrom(msg.sender, address(this), tokenAamount_);
        ERC20(_tokenA).transferFrom(msg.sender, _feeRecipient, tokenAamount_ * _protocolFee / BASIS_POINT);

        (uint256 tokenAAvailable_, uint256 tokenBAmount_) =
            _buyOrders.removeOrdersUntilTarget(tokenAamount_, _fulfillBuyLimitOrder);

        if (tokenAAvailable_ != tokenAamount_) ERC20(_tokenA).transfer(msg.sender, tokenAamount_ - tokenAAvailable_);
        ERC20(_tokenB).transfer(msg.sender, tokenAToTokenBDecimals(tokenBAmount_) / PRICE_PRECISION);
        emit SellMarketOrderFilled(tokenBAmount_ * PRICE_PRECISION / tokenAAvailable_, msg.sender, tokenBAmount_);
    }

    /**
     * @notice removes a buy limit order from the order book
     * @param orderId_ id of the order to remove
     * @param price_  tokenB/tokenA, not considering decimals, with `PRICE_PRECISION`
     */
    function removeBuyLimitOrder(uint48 orderId_, uint128 price_) public {
        (address maker_, uint256 amount_) = _buyOrders.removeOrder(price_, orderId_);
        if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);
        ERC20(_tokenB).transfer(maker_, tokenAToTokenB(amount_, price_));
        emit BuyLimitOrderCancelled(orderId_, price_, maker_, amount_);
    }

    /**
     * @notice removes a sell limit order from the order book
     * @param orderId_ id of the order to remove
     * @param price_  tokenA/tokenB, not considering decimals, with `PRICE_PRECISION`
     */
    function removeSellLimitOrder(uint48 orderId_, uint128 price_) public {
        (address maker_, uint256 amount_) = _sellOrders.removeOrder(price_, orderId_);
        if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);
        ERC20(_tokenA).transfer(maker_, tokenBToTokenA(amount_, price_));
        emit SellLimitOrderCancelled(orderId_, price_, maker_, amount_);
    }

    /**
     * @notice modifies a buy limit order
     * @dev reverts if the new price is the same as the old one
     * @param orderId_ id of the order to modify
     * @param oldPrice_ old tokenB/tokenA, not considering decimals, with `PRICE_PRECISION`
     * @param newPrice_ new tokenB/tokenA, not considering decimals, with `PRICE_PRECISION`
     * @param newAmount_ new amount of tokenA to buy
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function modifyBuyLimitOrder(
        uint48 orderId_,
        uint128 oldPrice_,
        uint128 newPrice_,
        uint256 newAmount_,
        uint128[] calldata prevs_,
        uint128[] calldata nexts_
    ) external {
        address maker_;
        uint256 oldAmount_;

        if (oldPrice_ == newPrice_) {
            (maker_, oldAmount_) = _buyOrders.modifyOrder(oldPrice_, orderId_, newAmount_);
            if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);
            if (oldAmount_ == newAmount_) revert SameAmountError(oldAmount_);
            newAmount_ < oldAmount_
                ? ERC20(_tokenB).transfer(maker_, tokenAToTokenB(oldAmount_ - newAmount_, oldPrice_))
                : ERC20(_tokenB).transferFrom(msg.sender, address(this), tokenAToTokenB(newAmount_ - oldAmount_, oldPrice_));
            emit BuyLimitOrderModified(orderId_, oldPrice_, maker_, newAmount_);
            return;
        }

        (maker_, oldAmount_) = _buyOrders.removeOrder(oldPrice_, orderId_);

        if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);

        _buyOrders.insertOrder(newPrice_, maker_, newAmount_, prevs_, nexts_);

        uint256 oldTokenBamount_ = tokenAToTokenB(oldAmount_, oldPrice_);
        uint256 newTokenBamount_ = tokenAToTokenB(newAmount_, newPrice_);

        emit BuyLimitOrderCancelled(orderId_, oldPrice_, maker_, oldAmount_);
        emit BuyLimitOrderPlaced(orderId_, newPrice_, maker_, newAmount_);

        if (oldTokenBamount_ == newTokenBamount_) return;

        newTokenBamount_ < oldTokenBamount_
            ? ERC20(_tokenB).transfer(maker_, oldTokenBamount_ - newTokenBamount_)
            : ERC20(_tokenB).transferFrom(msg.sender, address(this), newTokenBamount_ - oldTokenBamount_);
    }

    /**
     * @notice modifies a sell limit order
     * @dev reverts if the new price is the same as the old one
     * @param orderId_ id of the order to modify
     * @param oldPrice_ old tokenA/tokenB, not considering decimals, with `PRICE_PRECISION`
     * @param newPrice_ new tokenA/tokenB, not considering decimals, with `PRICE_PRECISION`
     * @param newAmount_ new amount of tokenA to buy
     * @param prevs_ hints for the previous price bracket
     * @param nexts_ hints for the next price bracket
     */
    function modifySellLimitOrder(
        uint48 orderId_,
        uint128 oldPrice_,
        uint128 newPrice_,
        uint256 newAmount_,
        uint128[] calldata prevs_,
        uint128[] calldata nexts_
    ) external {
        address maker_;
        uint256 oldAmount_;

        if (oldPrice_ == newPrice_) {
            (maker_, oldAmount_) = _sellOrders.modifyOrder(oldPrice_, orderId_, newAmount_);
            if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);
            if (oldAmount_ == newAmount_) revert SameAmountError(oldAmount_);
            newAmount_ < oldAmount_
                ? ERC20(_tokenA).transfer(maker_, tokenBToTokenA(oldAmount_ - newAmount_, oldPrice_))
                : ERC20(_tokenA).transferFrom(msg.sender, address(this), tokenBToTokenA(newAmount_ - oldAmount_, oldPrice_));
            emit SellLimitOrderModified(orderId_, oldPrice_, maker_, newAmount_);
            return;
        }

        (maker_, oldAmount_) = _sellOrders.removeOrder(oldPrice_, orderId_);

        if (maker_ != msg.sender) revert OnlyMakerError(msg.sender);

        _sellOrders.insertOrder(newPrice_, maker_, newAmount_, prevs_, nexts_);

        uint256 oldTokenAamount_ = tokenBToTokenA(oldAmount_, oldPrice_);
        uint256 newTokenAamount_ = tokenBToTokenA(newAmount_, newPrice_);

        emit SellLimitOrderCancelled(orderId_, oldPrice_, maker_, oldAmount_);
        emit SellLimitOrderPlaced(orderId_, newPrice_, maker_, newAmount_);

        if (oldTokenAamount_ == newTokenAamount_) return;

        newTokenAamount_ < oldTokenAamount_
            ? ERC20(_tokenA).transfer(maker_, oldTokenAamount_ - newTokenAamount_)
            : ERC20(_tokenA).transferFrom(msg.sender, address(this), newTokenAamount_ - oldTokenAamount_);
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

    function amountPlusFee(uint256 amount_) external pure returns (uint256) {
        return amount_ * (BASIS_POINT + _protocolFee) / BASIS_POINT;
    }

    function basisPoint() external pure returns (uint256) {
        return BASIS_POINT;
    }

    function _fulfillBuyLimitOrder(uint48 orderId_, uint128 price_, address maker_, uint256 amount_) internal {
        ERC20(_tokenA).transfer(maker_, amount_);
        emit BuyLimitOrderFilled(orderId_, price_, maker_, amount_);
    }

    function _fulfillSellLimitOrder(uint48 orderId_, uint128 price_, address maker_, uint256 amount_) internal {
        ERC20(_tokenB).transfer(maker_, amount_);
        emit SellLimitOrderFilled(orderId_, price_, maker_, amount_);
    }
}

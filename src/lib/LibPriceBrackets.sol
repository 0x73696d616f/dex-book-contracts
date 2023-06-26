// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { LibLinkedOrders } from "./LibLinkedOrders.sol";

library LibPriceBrackets {
    using LibLinkedOrders for LibLinkedOrders.LinkedOrders;

    uint128 internal constant PRICE_PRECISION = 10 ** 18;

    uint128 internal constant NULL = uint128(0);

    struct OrdersByPrice {
        uint128 price;
        LibLinkedOrders.Order[] orders;
    }

    struct PriceBracket {
        uint128 prev;
        uint128 next;
        LibLinkedOrders.LinkedOrders linkedOrders;
    }

    struct PriceBrackets {
        uint128 lowestPrice;
        uint128 highestPrice;
        mapping(uint128 => PriceBracket) priceBrackets;
    }

    error PriceSmallerThanPrevError();
    error PriceBiggerThanNextError();
    error PriceBracketDoesNotExistError();

    function insertOrder(
        PriceBrackets storage self,
        uint128 price_,
        address maker_,
        uint256 amount_,
        uint128[] calldata prevs_,
        uint128[] calldata nexts_
    ) internal returns (uint48 orderId_) {
        if (exists(self, price_)) {
            orderId_ = self.priceBrackets[price_].linkedOrders.insert(maker_, amount_);
            return orderId_;
        }

        uint128 prev_ = _findClosestPrev(self, prevs_, price_);
        uint128 next_ = _findClosestNext(self, nexts_, price_);

        self.priceBrackets[price_].prev = prev_;
        self.priceBrackets[price_].next = next_;
        orderId_ = self.priceBrackets[price_].linkedOrders.insert(maker_, amount_);

        prev_ == NULL ? self.lowestPrice = price_ : self.priceBrackets[prev_].next = price_;
        next_ == NULL ? self.highestPrice = price_ : self.priceBrackets[next_].prev = price_;
    }

    function removeOrder(PriceBrackets storage self, uint128 price_, uint48 orderId_)
        internal
        returns (address, uint256)
    {
        if (!exists(self, price_)) revert PriceBracketDoesNotExistError();
        (bool isEmpty_, address maker_, uint256 amount_) = self.priceBrackets[price_].linkedOrders.remove(orderId_);

        // only remove the price bracket if there are no orders left
        if (!isEmpty_) return (maker_, amount_);

        uint128 prev_ = self.priceBrackets[price_].prev;
        uint128 next_ = self.priceBrackets[price_].next;

        prev_ == NULL ? self.lowestPrice = next_ : self.priceBrackets[prev_].next = next_;
        next_ == NULL ? self.highestPrice = prev_ : self.priceBrackets[next_].prev = prev_;

        delete self.priceBrackets[price_];

        return (maker_, amount_);
    }

    function modifyOrder(PriceBrackets storage self, uint128 price_, uint48 orderId_, uint256 newAmount_)
        internal
        returns (address, uint256)
    {
        if (!exists(self, price_)) revert PriceBracketDoesNotExistError();
        return self.priceBrackets[price_].linkedOrders.modify(orderId_, newAmount_);
    }

    function removeOrdersUntilTarget(
        PriceBrackets storage self,
        uint256 targetAmount_,
        function(uint48,uint128,address,uint256) internal _f
    ) internal returns (uint256 accumulatedAmount_, uint256 accumulatedCost_) {
        uint128 initialLowestPrice_ = self.lowestPrice;
        uint128 currentPrice_ = initialLowestPrice_;
        if (currentPrice_ == NULL) return (0, 0);

        uint256 currentAmount_;
        uint128 nextPrice_;
        bool isEmpty_;
        while (accumulatedAmount_ < targetAmount_ && currentPrice_ != NULL) {
            (currentAmount_, isEmpty_) = self.priceBrackets[currentPrice_].linkedOrders.removeUntilTarget(
                targetAmount_ - accumulatedAmount_, currentPrice_, _f
            );
            accumulatedAmount_ += currentAmount_;
            accumulatedCost_ += currentAmount_ * PRICE_PRECISION ** 2 / currentPrice_;
            nextPrice_ = self.priceBrackets[currentPrice_].next;
            if (isEmpty_) {
                delete self.priceBrackets[currentPrice_];
                currentPrice_ = nextPrice_;
            }
        }

        // only update lowest price if it changed
        if (currentPrice_ != initialLowestPrice_) self.lowestPrice = currentPrice_;

        // if the currentPrice_ is NULL, there are no more price brackets left
        if (currentPrice_ == NULL) delete self.highestPrice;
    }

    function exists(PriceBrackets storage self, uint128 price_) internal view returns (bool) {
        return self.priceBrackets[price_].linkedOrders.head != 0;
    }

    function _findClosestPrev(PriceBrackets storage self, uint128[] calldata prevs_, uint128 price_)
        internal
        view
        returns (uint128 prev_)
    {
        // find the first prev that exists
        uint256 i_;
        while (!exists(self, prevs_[i_]) && prevs_[i_] != NULL) {
            unchecked {
                ++i_;
            }
            if (i_ == prevs_.length) revert PriceBracketDoesNotExistError();
        }
        uint128 nextPrev_ = prevs_[i_];

        // set the lowest price if no prevs exist and the price is bigger than the lowest price
        if (nextPrev_ == NULL && price_ > self.lowestPrice) nextPrev_ = self.lowestPrice;

        // find the closest prev to price
        while (nextPrev_ < price_ && nextPrev_ != NULL) {
            prev_ = nextPrev_;
            nextPrev_ = self.priceBrackets[prev_].next;
        }

        if (price_ <= prev_) revert PriceSmallerThanPrevError();
    }

    function _findClosestNext(PriceBrackets storage self, uint128[] calldata nexts_, uint128 price_)
        internal
        view
        returns (uint128 next_)
    {
        // find the first next that exists
        uint256 i_;
        while (!exists(self, nexts_[i_]) && nexts_[i_] != NULL) {
            unchecked {
                ++i_;
            }
            if (i_ == nexts_.length) revert PriceBracketDoesNotExistError();
        }
        uint128 prevNext_ = nexts_[i_];

        // set the highest price if no nexts exist and the price is lower than the highest price
        uint128 highestPrice_ = self.highestPrice;
        if (prevNext_ == NULL && price_ < highestPrice_) prevNext_ = self.highestPrice;

        // find the closest next to price
        while (prevNext_ > price_) {
            next_ = prevNext_;
            prevNext_ = self.priceBrackets[next_].prev;
        }

        if (price_ >= next_ && next_ != NULL) revert PriceBiggerThanNextError();
    }

    function getPrices(PriceBrackets storage self) internal view returns (uint128[] memory prices_) {
        uint256 length_;
        uint128 curr_ = self.lowestPrice;
        if (curr_ == 0) return new uint128[](0);

        prices_ = new uint128[](5000);
        while (curr_ != 0) {
            prices_[length_++] = curr_;
            curr_ = self.priceBrackets[curr_].next;
        }

        uint128[] memory correctPrices_ = new uint128[](length_);
        for (uint256 i_ = 0; i_ < length_; i_++) {
            correctPrices_[i_] = prices_[i_];
        }

        return correctPrices_;
    }

    function getOrdersAtPrice(PriceBrackets storage self, uint128 price_)
        internal
        view
        returns (LibLinkedOrders.Order[] memory)
    {
        return self.priceBrackets[price_].linkedOrders.getOrders();
    }

    function getOrderAtPrice(PriceBrackets storage self, uint128 price_, uint48 orderId_)
        internal
        view
        returns (LibLinkedOrders.Order memory)
    {
        return self.priceBrackets[price_].linkedOrders.orders[orderId_];
    }

    function getOrdersAndPrices(PriceBrackets storage self)
        internal
        view
        returns (OrdersByPrice[] memory correctOrdersByPrices_)
    {
        uint256 length_;
        uint128 curr_ = self.lowestPrice;
        if (curr_ == 0) return (new OrdersByPrice[](0));

        OrdersByPrice[] memory ordersByPrices_ = new OrdersByPrice[](5000);
        while (curr_ != 0) {
            LibLinkedOrders.Order[] memory priceOrders_ = getOrdersAtPrice(self, curr_);
            ordersByPrices_[length_++] = OrdersByPrice(curr_, priceOrders_);
            curr_ = self.priceBrackets[curr_].next;
        }

        correctOrdersByPrices_ = new OrdersByPrice[](length_);
        for (curr_ = 0; curr_ < length_; curr_++) {
            correctOrdersByPrices_[curr_] = ordersByPrices_[curr_];
        }
    }
}

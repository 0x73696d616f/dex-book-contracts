// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import { LibLinkedOrders } from "./LibLinkedOrders.sol";

library LibPriceBrackets {
    using LibLinkedOrders for LibLinkedOrders.LinkedOrders;

    uint128 internal constant NULL = uint128(0);

    struct PriceBracket {
        uint128 prev;
        uint128 next;
        uint256 accumulatedAmount;
        LibLinkedOrders.LinkedOrders orders;
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
    ) internal returns (uint256 orderId_) {
        if (exists(self, price_)) {
            self.priceBrackets[price_].accumulatedAmount += amount_;
            orderId_ = self.priceBrackets[price_].orders.insert(maker_, amount_);
            return orderId_;
        }

        uint128 prev_ = _findClosestPrev(self, prevs_, price_);
        uint128 next_ = _findClosestNext(self, nexts_, price_);

        self.priceBrackets[price_].prev = prev_;
        self.priceBrackets[price_].next = next_;
        self.priceBrackets[price_].accumulatedAmount = amount_;
        orderId_ = self.priceBrackets[price_].orders.insert(maker_, amount_);

        prev_ == NULL ? self.lowestPrice = price_ : self.priceBrackets[prev_].next = price_;
        next_ == NULL ? self.highestPrice = price_ : self.priceBrackets[next_].prev = price_;
    }

    function removeOrder(PriceBrackets storage self, uint128 price_, uint48 orderId_) internal {
        if (!exists(self, price_)) revert PriceBracketDoesNotExistError();
        uint256 amount_ = self.priceBrackets[price_].orders.remove(orderId_);
        uint256 accumulatedAmount_ = self.priceBrackets[price_].accumulatedAmount;

        // only remove the price bracket if there are no orders left
        if (accumulatedAmount_ != amount_) {
            self.priceBrackets[price_].accumulatedAmount = accumulatedAmount_ - amount_;
            return;
        }

        uint128 prev_ = self.priceBrackets[price_].prev;
        uint128 next_ = self.priceBrackets[price_].next;

        prev_ == NULL ? self.lowestPrice = next_ : self.priceBrackets[prev_].next = next_;
        next_ == NULL ? self.highestPrice = prev_ : self.priceBrackets[next_].prev = prev_;

        delete self.priceBrackets[price_];
    }

    function removeOrdersUntilTarget(PriceBrackets storage self, uint256 targetAmount_)
        internal
        returns (uint256, uint256)
    {
        uint128 currentPrice_ = self.lowestPrice;
        if (currentPrice_ == NULL) return (0, 0);

        uint256 accumulatedAmount_;
        uint256 accumulatedCost_;
        uint256 currentAmount_ = self.priceBrackets[currentPrice_].accumulatedAmount;
        uint128 nextPrice_;
        while (accumulatedAmount_ + currentAmount_ <= targetAmount_ && currentPrice_ != NULL) {
            self.priceBrackets[currentPrice_].orders.removeUntilTarget(targetAmount_ - accumulatedAmount_);
            accumulatedAmount_ += currentAmount_;
            accumulatedCost_ += currentAmount_ * currentPrice_;
            nextPrice_ = self.priceBrackets[currentPrice_].next;
            delete self.priceBrackets[currentPrice_];
            currentPrice_ = nextPrice_;
            currentAmount_ = self.priceBrackets[currentPrice_].accumulatedAmount;
        }

        // if the currentPrice_ is NULL, there are no more price brackets left
        if (currentPrice_ == NULL) {
            delete self.highestPrice;
            return (accumulatedAmount_, accumulatedCost_);
        }

        // update the lowest price if price brackets have been deleted
        if (accumulatedAmount_ != 0) self.lowestPrice = currentPrice_;

        // if the accumulated amount is equal to the target amount, return the accumulated cost
        if (accumulatedAmount_ == targetAmount_) return (accumulatedAmount_, accumulatedCost_);

        // if the accumulated amount is smaller than the target amount, do a partial fulfillment of the target amount
        uint256 remainingAmount_ = targetAmount_ - accumulatedAmount_;
        self.priceBrackets[currentPrice_].accumulatedAmount -= remainingAmount_;
        self.priceBrackets[currentPrice_].orders.removeUntilTarget(remainingAmount_);
        return (targetAmount_, accumulatedCost_ + remainingAmount_ * currentPrice_);
    }

    function exists(PriceBrackets storage self, uint128 price_) internal view returns (bool) {
        return self.priceBrackets[price_].accumulatedAmount != 0;
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

        if (price_ < prev_) revert PriceSmallerThanPrevError();
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

        if (price_ > next_ && next_ != NULL) revert PriceBiggerThanNextError();
    }
}

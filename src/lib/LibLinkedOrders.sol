// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

library LibLinkedOrders {
    uint48 internal constant NULL = uint48(0);

    /**
     * @notice Order is a struct that contains the maker, amount, and price of an order.
     * @param maker is the address of the order maker
     * @param prev is the previous order in the linked list of orders
     * @param next is the next order in the linked list of orders
     * @param amount is the amount of token to be traded
     */
    struct Order {
        address maker;
        uint48 prev;
        uint48 next;
        uint256 amount;
    }

    /**
     * @notice LinkedOrders is a struct that contains the head, tail, and length of a linked list of orders.
     * @param orders is a mapping from orderId to Order
     * @param head is the head of the linked list of orders
     * @param tail is the tail of the linked list of orders
     * @param length is the length of the linked list of orders
     */
    struct LinkedOrders {
        uint48 head;
        uint48 tail;
        uint48 length;
        mapping(uint48 => Order) orders;
    }

    /**
     * @notice inserts an order at the bottom of a linked list of orders
     * @param self is the linked list of orders
     * @param maker_ is the address of the order maker
     * @param amount_ is the amount of token to be traded
     */
    function insert(LinkedOrders storage self, address maker_, uint256 amount_) internal returns (uint48 orderId_) {
        orderId_ = ++self.length;
        uint48 tailOrderId_ = self.tail;
        self.orders[orderId_] = Order(maker_, tailOrderId_, NULL, amount_);
        tailOrderId_ == NULL ? self.head = orderId_ : self.orders[tailOrderId_].next = orderId_;
        self.tail = orderId_;
    }

    /**
     * @notice removes an order from a linked list of orders
     * @param self is the linked list of orders
     * @param id_ is the id of the order to be removed
     */
    function remove(LinkedOrders storage self, uint48 id_) internal returns (uint256) {
        return remove(self, self.orders[id_].prev, id_, self.orders[id_].next);
    }

    /**
     * @notice removes an order from a linked list of orders
     * @param self is the linked list of orders
     * @param id_ is the id of the order to be removed
     * @param nextId_ is the id of the order after the order to be removed
     */
    function remove(LinkedOrders storage self, uint48 prevId_, uint48 id_, uint48 nextId_) internal returns (uint256) {
        if (id_ == self.head) {
            self.head = nextId_;
        } else {
            self.orders[prevId_].next = nextId_;
        }

        if (id_ == self.tail) {
            self.tail = prevId_;
        } else {
            self.orders[nextId_].prev = prevId_;
        }

        uint256 amount_ = self.orders[id_].amount;
        delete self.orders[id_];
        return amount_;
    }

    /**
     * @notice removes orders from a linked list of orders until the target amount is reached.
     *         Useful to fulfill market orders
     * @dev    deletes orders until the target amount is reached in the while loop. If the target amount is reached
     *         after removing the last order, returns. Else, does a partial fulfillment of the last order, if it exists
     * @param self is the linked list of orders
     * @param targetAmount_ is the cummulative amount to be removed
     */
    function removeUntilTarget(LinkedOrders storage self, uint256 targetAmount_) internal returns (uint256) {
        uint48 id_ = self.head;
        if (id_ == NULL) return 0; // no orders to remove

        uint256 amount_ = self.orders[id_].amount;
        uint256 accumulatedAmount_;
        uint48 prevId_;
        uint48 nextId_;
        while (id_ != NULL && accumulatedAmount_ + amount_ <= targetAmount_) {
            accumulatedAmount_ += amount_;
            nextId_ = self.orders[id_].next;
            remove(self, id_, prevId_, nextId_);
            prevId_ = id_;
            id_ = nextId_;
            amount_ = self.orders[id_].amount;
        }

        if (id_ == NULL || accumulatedAmount_ == targetAmount_) return accumulatedAmount_; // no orders left or reached target

        self.orders[id_].amount = amount_ - (targetAmount_ - accumulatedAmount_);
        return targetAmount_;
    }
}

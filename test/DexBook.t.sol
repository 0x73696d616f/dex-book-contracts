// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "@forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import { LibLinkedOrders } from "src/lib/LibLinkedOrders.sol";
import { LibPriceBrackets } from "src/lib/LibPriceBrackets.sol";
import { DexBook } from "src/DexBook.sol";

contract USDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DexBookTest is Test {
    DexBook public dexBook;
    ERC20 public eth;
    USDC public usdc;

    address public deployer;
    address public alice;
    address public bob;

    function setUp() external {
        eth = new ERC20("Ether", "ETH");
        usdc = new USDC();
        vm.label(address(eth), "ETH");
        vm.label(address(usdc), "USDC");

        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(deployer);
        dexBook = new DexBook(address(eth), address(usdc));
    }

    function test_DexBook_setup() public {
        assertEq(dexBook.tokenA(), address(eth));
        assertEq(dexBook.tokenB(), address(usdc));
        assertEq(dexBook.tokenADecimals(), 18);
        assertEq(dexBook.tokenBDecimals(), 6);
        assertEq(dexBook.feeRecipient(), deployer);
        assertEq(dexBook.protocolFee(), 10);
    }

    function test_DexBook_placeAndFulfillSellOrder() public {
        uint128 tokenAtoTokenBPrice_ = 1000 * dexBook.pricePrecision();
        uint256 ethAmount_ = 5e18;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_);

        deal(address(eth), alice, _amountPlusFee(ethAmount_));

        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        vm.startPrank(alice);
        eth.approve(address(dexBook), _amountPlusFee(ethAmount_));
        dexBook.placeSellLimitOrder(usdcAmount_, tokenAtoTokenBPrice_, prevs_, nexts_);
        vm.stopPrank();

        assertEq(eth.balanceOf(alice), 0);
        assertEq(eth.balanceOf(address(dexBook)), ethAmount_);
        assertEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.sellOrdersAndPrices();

        assertEq(usdcAmount_, 5e9);
        assertEq(ordersByPrice_.length, 1);
        assertEq(ordersByPrice_[0].orders.length, 1);
        assertEq(ordersByPrice_[0].orders[0].maker, alice);
        assertEq(ordersByPrice_[0].orders[0].amount, usdcAmount_);

        assertEq(ordersByPrice_[0].price, tokenAtoTokenBPrice_);

        // Fill the order

        deal(address(usdc), bob, _amountPlusFee(usdcAmount_));

        vm.startPrank(bob);
        usdc.approve(address(dexBook), _amountPlusFee(usdcAmount_));
        dexBook.placeBuyMarketOrder(usdcAmount_);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), usdcAmount_);
        assertEq(usdc.balanceOf(address(dexBook)), 0);
        assertEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));
        assertEq(usdc.balanceOf(bob), 0);

        assertEq(ethAmount_, 5e18);
        assertEq(eth.balanceOf(bob), ethAmount_);
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));
        assertEq(eth.balanceOf(alice), 0);
    }

    function test_DexBook_placeAndFulfillBuyOrder() public {
        uint128 tokenAtoTokenBPrice_ = 1000 * dexBook.pricePrecision();
        uint128 tokenBtoTokenAPrice_ = dexBook.invertPrice(tokenAtoTokenBPrice_);
        uint256 ethAmount_ = 5e18;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_);

        deal(address(usdc), bob, _amountPlusFee(usdcAmount_));

        uint128[] memory prevs_ = new uint128[](1);
        uint128[] memory nexts_ = new uint128[](1);
        prevs_[0] = 0;
        nexts_[0] = 0;

        vm.startPrank(bob);
        usdc.approve(address(dexBook), _amountPlusFee(usdcAmount_));
        dexBook.placeBuyLimitOrder(ethAmount_, tokenBtoTokenAPrice_, prevs_, nexts_);
        vm.stopPrank();

        assertEq(usdc.balanceOf(bob), 0);
        assertEq(usdc.balanceOf(address(dexBook)), usdcAmount_);
        assertEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.buyOrdersAndPrices();

        assertEq(ordersByPrice_.length, 1);
        assertEq(ordersByPrice_[0].orders.length, 1);
        assertEq(ordersByPrice_[0].orders[0].maker, bob);
        assertEq(ordersByPrice_[0].orders[0].amount, ethAmount_);

        assertEq(ordersByPrice_[0].price, tokenBtoTokenAPrice_);

        // Fill the order

        deal(address(eth), alice, _amountPlusFee(ethAmount_));

        vm.startPrank(alice);
        eth.approve(address(dexBook), _amountPlusFee(ethAmount_));
        dexBook.placeSellMarketOrder(ethAmount_);
        vm.stopPrank();

        assertEq(usdcAmount_, 5e9);
        assertEq(usdc.balanceOf(alice), usdcAmount_);
        assertEq(usdc.balanceOf(address(dexBook)), 0);
        assertEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));
        assertEq(usdc.balanceOf(bob), 0);

        assertEq(ethAmount_, 5e18);
        assertEq(eth.balanceOf(bob), ethAmount_);
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));
        assertEq(eth.balanceOf(alice), 0);
    }

    function test_placeSeveralSellOrdersAndFulfillMarketBuyOrder() public {
        uint256 usdcAmount_ = _placeSellLimitOrder(bob, 5e18, 1000);
        usdcAmount_ += _placeSellLimitOrder(bob, 4e18, 800);
        usdcAmount_ += _placeSellLimitOrder(bob, 6e18, 1200);
        usdcAmount_ += _placeSellLimitOrder(bob, 3e18, 1200);
        usdcAmount_ += _placeSellLimitOrder(bob, 2e18, 800);
        usdcAmount_ += _placeSellLimitOrder(bob, 1e18, 1000);

        // Fill the orders

        uint256 ethAmount_ = 5e18 + 4e18 + 6e18 + 3e18 + 2e18 + 1e18;
        assertApproxEq(usdcAmount_, 21e9);
        assertEq(ethAmount_, 21e18);
        deal(address(usdc), alice, _amountPlusFee(usdcAmount_));
        vm.startPrank(alice);
        usdc.approve(address(dexBook), _amountPlusFee(usdcAmount_));
        dexBook.placeBuyMarketOrder(usdcAmount_);
        vm.stopPrank();

        assertApproxEq(eth.balanceOf(alice), ethAmount_); // rounding error
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertApproxEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));

        assertApproxEq(usdc.balanceOf(bob), usdcAmount_);
        assertEq(usdc.balanceOf(address(dexBook)), 0);
        assertApproxEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.sellOrdersAndPrices();
        assertEq(ordersByPrice_.length, 0);

        // insert again

        uint256 partialUsdcAmount_ = _placeSellLimitOrder(makeAddr("1000_5e18"), 5e18, 1000);
        partialUsdcAmount_ += _placeSellLimitOrder(makeAddr("800_4e18"), 4e18, 800);
        partialUsdcAmount_ += _placeSellLimitOrder(makeAddr("1200_6e18"), 6e18, 1200);
        _placeSellLimitOrder(makeAddr("1200_3e18"), 3e18, 1200);
        partialUsdcAmount_ += _placeSellLimitOrder(makeAddr("800_2e18"), 2e18, 800);
        partialUsdcAmount_ += _placeSellLimitOrder(makeAddr("1000_1e18"), 1e18, 1000);

        // fill some orders

        uint256 partialEthAmount_ = 4e18 + 2e18 + 5e18 + 1e18 + 6e18;
        assertApproxEq(partialUsdcAmount_, 18e9);
        deal(address(usdc), alice, _amountPlusFee(partialUsdcAmount_));
        vm.startPrank(alice);
        usdc.approve(address(dexBook), _amountPlusFee(partialUsdcAmount_));
        dexBook.placeBuyMarketOrder(partialUsdcAmount_);
        vm.stopPrank();

        assertApproxEq(eth.balanceOf(alice), ethAmount_ + partialEthAmount_);
        assertApproxEq(eth.balanceOf(address(dexBook)), ethAmount_ - partialEthAmount_);
        assertApproxEq(eth.balanceOf(deployer), _feeAmount(ethAmount_ + partialEthAmount_));

        assertApproxEq(usdc.balanceOf(makeAddr("800_4e18")), _ethToUsdcNoPrecision(4e18, 800));
        assertApproxEq(usdc.balanceOf(makeAddr("800_2e18")), _ethToUsdcNoPrecision(2e18, 800));
        assertApproxEq(usdc.balanceOf(makeAddr("1000_5e18")), _ethToUsdcNoPrecision(5e18, 1000));
        assertApproxEq(usdc.balanceOf(makeAddr("1000_1e18")), _ethToUsdcNoPrecision(1e18, 1000));
        assertApproxEq(usdc.balanceOf(makeAddr("1200_6e18")), _ethToUsdcNoPrecision(6e18, 1200));

        ordersByPrice_ = dexBook.sellOrdersAndPrices();

        assertEq(ordersByPrice_.length, 1);

        assertEq(ordersByPrice_[0].orders.length, 1);
        assertEq(ordersByPrice_[0].price, 1200 * dexBook.pricePrecision());
        assertEq(ordersByPrice_[0].orders[0].maker, makeAddr("1200_3e18"));
        assertEq(ordersByPrice_[0].orders[0].amount, _ethToUsdc(3e18, 1200 * dexBook.pricePrecision()));
    }

    function test_placeSeveralBuyOrdersAndFulfillMarketSellOrder() public {
        uint256 usdcAmount_ = _placeBuyLimitOrder(bob, 5e18, 1000);
        usdcAmount_ += _placeBuyLimitOrder(bob, 4e18, 800);
        usdcAmount_ += _placeBuyLimitOrder(bob, 6e18, 1200);
        usdcAmount_ += _placeBuyLimitOrder(bob, 3e18, 1200);
        usdcAmount_ += _placeBuyLimitOrder(bob, 2e18, 800);
        usdcAmount_ += _placeBuyLimitOrder(bob, 1e18, 1000);

        // Fill the orders

        uint256 ethAmount_ = 5e18 + 4e18 + 6e18 + 3e18 + 2e18 + 1e18;
        assertApproxEq(usdcAmount_, 21e9);
        assertEq(ethAmount_, 21e18);
        deal(address(eth), alice, _amountPlusFee(ethAmount_));
        vm.startPrank(alice);
        eth.approve(address(dexBook), _amountPlusFee(ethAmount_));
        dexBook.placeSellMarketOrder(ethAmount_);
        vm.stopPrank();

        assertApproxEq(usdc.balanceOf(alice), usdcAmount_);
        assertEq(usdc.balanceOf(address(dexBook)), 0);
        assertApproxEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_));

        assertApproxEq(eth.balanceOf(bob), ethAmount_);
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertApproxEq(eth.balanceOf(deployer), _feeAmount(ethAmount_));

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.buyOrdersAndPrices();
        assertEq(ordersByPrice_.length, 0);

        // insert again

        uint256 partialUsdcAmount_ = _placeBuyLimitOrder(makeAddr("1000_5e18"), 5e18, 1000);
        _placeBuyLimitOrder(makeAddr("800_4e18"), 4e18, 800);
        partialUsdcAmount_ += _placeBuyLimitOrder(makeAddr("1200_6e18"), 6e18, 1200);
        partialUsdcAmount_ += _placeBuyLimitOrder(makeAddr("1200_3e18"), 3e18, 1200);
        partialUsdcAmount_ += _placeBuyLimitOrder(makeAddr("800_2e18"), 2e18, 800);
        partialUsdcAmount_ += _placeBuyLimitOrder(makeAddr("1000_1e18"), 1e18, 1000);

        // fill some orders

        uint256 partialEthAmount_ = 3e18 + 2e18 + 5e18 + 1e18 + 6e18;
        assertApproxEq(partialUsdcAmount_, 18e9);
        deal(address(eth), alice, _amountPlusFee(partialEthAmount_));
        vm.startPrank(alice);
        eth.approve(address(dexBook), _amountPlusFee(partialEthAmount_));
        dexBook.placeSellMarketOrder(partialEthAmount_);
        vm.stopPrank();

        assertApproxEq(usdc.balanceOf(alice), usdcAmount_ + partialUsdcAmount_);
        assertApproxEq(usdc.balanceOf(address(dexBook)), usdcAmount_ - partialUsdcAmount_);
        assertApproxEq(usdc.balanceOf(deployer), _feeAmount(usdcAmount_ + partialUsdcAmount_));

        assertEq(eth.balanceOf(alice), 0);
        assertEq(eth.balanceOf(address(dexBook)), 0);
        assertApproxEq(eth.balanceOf(deployer), _feeAmount(ethAmount_ + partialEthAmount_));

        assertApproxEq(eth.balanceOf(makeAddr("1200_6e18")), 6e18);
        assertApproxEq(eth.balanceOf(makeAddr("1200_3e18")), 3e18);
        assertApproxEq(eth.balanceOf(makeAddr("1000_5e18")), 5e18);
        assertApproxEq(eth.balanceOf(makeAddr("1000_1e18")), 1e18);
        assertApproxEq(eth.balanceOf(makeAddr("800_4e18")), 2e18);
        assertEq(eth.balanceOf(makeAddr("800_2e18")), 0);

        ordersByPrice_ = dexBook.buyOrdersAndPrices();

        assertEq(ordersByPrice_.length, 1);

        assertEq(ordersByPrice_.length, 1);
        assertEq(ordersByPrice_[0].price, dexBook.invertPrice(800 * dexBook.pricePrecision()));
        assertEq(ordersByPrice_[0].orders.length, 2);
        assertEq(ordersByPrice_[0].orders[0].maker, makeAddr("800_4e18"));
        assertEq(ordersByPrice_[0].orders[0].amount, 2e18);
        assertEq(ordersByPrice_[0].orders[1].maker, makeAddr("800_2e18"));
        assertEq(ordersByPrice_[0].orders[1].amount, 2e18);
    }

    function test_placeAndRemoveBuyLimitOrder() public {
        _placeBuyLimitOrder(bob, 5e18, 1000);
        _placeBuyLimitOrder(bob, 4e18, 800);
        _placeBuyLimitOrder(bob, 6e18, 1200);
        _placeBuyLimitOrder(bob, 6e18, 1200);
        _placeBuyLimitOrder(bob, 2e18, 1200);

        _removeBuyLimitOrder(bob, 1000, 1);
        _removeBuyLimitOrder(bob, 800, 1);
        _removeBuyLimitOrder(bob, 1200, 2);
        _removeBuyLimitOrder(bob, 1200, 3);
        _removeBuyLimitOrder(bob, 1200, 1);
    }

    function test_placeAndRemoveSellLimitOrder() public {
        _placeSellLimitOrder(bob, 5e18, 1000);
        _placeSellLimitOrder(bob, 4e18, 800);
        _placeSellLimitOrder(bob, 6e18, 1200);
        _placeSellLimitOrder(bob, 6e18, 1200);
        _placeSellLimitOrder(bob, 2e18, 1200);

        _removeSellLimitOrder(bob, 1000, 1);
        _removeSellLimitOrder(bob, 800, 1);
        _removeSellLimitOrder(bob, 1200, 2);
        _removeSellLimitOrder(bob, 1200, 3);
        _removeSellLimitOrder(bob, 1200, 1);
    }

    function test_placeAndModifyBuyLimitOrders() public {
        _placeBuyLimitOrder(bob, 5e18, 1000);
        _increaseBuyLimitOrderAmountAndIncreasePrice(bob, 1, 1000, 100, 1e18);
        _increaseBuyLimitOrderAmountAndIncreasePrice(bob, 1, 1100, 0, 1e18);
        _increaseBuyLimitOrderAmountAndDecreasePrice(bob, 1, 1100, 100, 0);
        _increaseBuyLimitOrderAmountAndDecreasePrice(bob, 1, 1000, 100, 2e18);
        _decreaseBuyLimitOrderAmountAndIncreasePrice(bob, 1, 900, 100, 0);
        _decreaseBuyLimitOrderAmountAndIncreasePrice(bob, 1, 1000, 100, 1e18);
        _decreaseBuyLimitOrderAmountAndDecreasePrice(bob, 1, 1100, 100, 1e18);
    }

    function test_placeAndModifySellLimitOrders() public {
        _placeSellLimitOrder(bob, 5e18, 1000);
        _increaseSellLimitOrderAmountAndIncreasePrice(bob, 1, 1000, 100, 1e18);
        _increaseSellLimitOrderAmountAndIncreasePrice(bob, 1, 1100, 0, 1e18);
        _increaseSellLimitOrderAmountAndDecreasePrice(bob, 1, 1100, 100, 0);
        _increaseSellLimitOrderAmountAndDecreasePrice(bob, 1, 1000, 100, 2e18);
        _decreaseSellLimitOrderAmountAndIncreasePrice(bob, 1, 900, 100, 0);
        _decreaseSellLimitOrderAmountAndIncreasePrice(bob, 1, 1000, 100, 1e18);
        _decreaseSellLimitOrderAmountAndDecreasePrice(bob, 1, 1100, 100, 1e18);
        _decreaseSellLimitOrderAmountAndDecreasePrice(bob, 1, 1000, 100, 0);
    }

    function _placeBuyLimitOrder(address user_, uint256 ethAmount_, uint128 tokenAtoTokenBPrice_)
        internal
        returns (uint256)
    {
        tokenAtoTokenBPrice_ = tokenAtoTokenBPrice_ * dexBook.pricePrecision();
        uint128 tokenBtoTokenAPrice_ = dexBook.invertPrice(tokenAtoTokenBPrice_);

        uint256 initialDexBookUsdcBalance_ = usdc.balanceOf(address(dexBook));
        uint256 initialDeployerUsdcBalance_ = usdc.balanceOf(deployer);
        uint256 initialUserUsdcBalance_ = usdc.balanceOf(user_);

        deal(
            address(usdc), user_, initialUserUsdcBalance_ + _amountPlusFee(_ethToUsdc(ethAmount_, tokenAtoTokenBPrice_))
        );

        uint128[] memory prevsAndNexts_ = new uint128[](1);
        prevsAndNexts_[0] = 0;

        LibPriceBrackets.OrdersByPrice[] memory initialOrdersByPrice_ = dexBook.buyOrdersAndPrices();

        vm.startPrank(user_);
        usdc.approve(address(dexBook), _amountPlusFee(_ethToUsdc(ethAmount_, tokenAtoTokenBPrice_)));
        uint48 orderId_ = dexBook.placeBuyLimitOrder(ethAmount_, tokenBtoTokenAPrice_, prevsAndNexts_, prevsAndNexts_);
        vm.stopPrank();

        assertApproxEq(
            usdc.balanceOf(address(dexBook)), initialDexBookUsdcBalance_ + _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_)
        );
        assertApproxEq(
            usdc.balanceOf(deployer),
            initialDeployerUsdcBalance_ + _feeAmount(_ethToUsdc(ethAmount_, tokenAtoTokenBPrice_))
        );

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.buyOrdersAndPrices();

        if (_isInArray(initialOrdersByPrice_, tokenBtoTokenAPrice_)) {
            assertTrue(_compareArrays(initialOrdersByPrice_, ordersByPrice_));
            assertTrue(_arePricesOrdered(ordersByPrice_));
        } else {
            assertTrue(_isInArray(ordersByPrice_, tokenBtoTokenAPrice_));
            assertTrue(_arePricesOrdered(ordersByPrice_));
            assertEq(ordersByPrice_.length, initialOrdersByPrice_.length + 1);
        }

        assertEq(dexBook.buyOrderAtPrice(tokenBtoTokenAPrice_, orderId_).maker, user_);
        assertApproxEq(
            dexBook.buyOrderAtPrice(tokenBtoTokenAPrice_, orderId_).amount, _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_)
        );

        return _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_);
    }

    function _placeSellLimitOrder(address user_, uint256 ethAmount_, uint128 tokenAtoTokenBPrice_)
        internal
        returns (uint256)
    {
        tokenAtoTokenBPrice_ = tokenAtoTokenBPrice_ * dexBook.pricePrecision();

        uint256 initialDexBookEthBalance_ = eth.balanceOf(address(dexBook));
        uint256 initialDeployerEthBalance_ = eth.balanceOf(deployer);
        uint256 initialUserEthBalance_ = eth.balanceOf(user_);

        uint128[] memory prevsAndNexts_ = new uint128[](1);
        prevsAndNexts_[0] = 0;

        LibPriceBrackets.OrdersByPrice[] memory initialOrdersByPrice_ = dexBook.sellOrdersAndPrices();

        deal(address(eth), user_, initialUserEthBalance_ + _amountPlusFee(ethAmount_));
        vm.startPrank(user_);
        eth.approve(address(dexBook), _amountPlusFee(ethAmount_));
        uint48 orderId_ = dexBook.placeSellLimitOrder(
            _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_), tokenAtoTokenBPrice_, prevsAndNexts_, prevsAndNexts_
        );
        vm.stopPrank();

        assertApproxEq(eth.balanceOf(address(dexBook)), initialDexBookEthBalance_ + ethAmount_);
        assertApproxEq(eth.balanceOf(deployer), initialDeployerEthBalance_ + _feeAmount(ethAmount_));

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.sellOrdersAndPrices();

        if (_isInArray(initialOrdersByPrice_, tokenAtoTokenBPrice_)) {
            assertTrue(_compareArrays(initialOrdersByPrice_, ordersByPrice_));
            assertTrue(_arePricesOrdered(ordersByPrice_));
        } else {
            assertTrue(_isInArray(ordersByPrice_, tokenAtoTokenBPrice_));
            assertTrue(_arePricesOrdered(ordersByPrice_));
            assertEq(ordersByPrice_.length, initialOrdersByPrice_.length + 1);
        }

        assertEq(dexBook.sellOrderAtPrice(tokenAtoTokenBPrice_, orderId_).maker, user_);
        assertApproxEq(
            dexBook.sellOrderAtPrice(tokenAtoTokenBPrice_, orderId_).amount,
            _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_)
        );

        return _ethToUsdc(ethAmount_, tokenAtoTokenBPrice_);
    }

    function _removeBuyLimitOrder(address user_, uint128 price_, uint48 orderId_) internal {
        price_ = dexBook.pricePrecision() / price_;
        uint256 initialDexBookUsdcBalance_ = usdc.balanceOf(address(dexBook));
        uint256 initialUserUsdcBalance_ = usdc.balanceOf(user_);

        LibPriceBrackets.OrdersByPrice[] memory initialOrdersByPrice_ = dexBook.buyOrdersAndPrices();

        uint256 ethAmount_ = dexBook.buyOrderAtPrice(price_, orderId_).amount;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, dexBook.pricePrecision() ** 2 / price_);

        vm.prank(user_);
        dexBook.removeBuyLimitOrder(orderId_, price_);

        assertApproxEq(usdc.balanceOf(address(dexBook)), initialDexBookUsdcBalance_ - usdcAmount_);
        assertApproxEq(usdc.balanceOf(user_), initialUserUsdcBalance_ + usdcAmount_);

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.buyOrdersAndPrices();

        assertTrue(_arePricesOrdered(initialOrdersByPrice_));
        assertTrue(_arePricesOrdered(ordersByPrice_));

        if (_isInArray(initialOrdersByPrice_, price_) && _isInArray(ordersByPrice_, price_)) {
            assertTrue(_compareArrays(initialOrdersByPrice_, ordersByPrice_));
        } else {
            assertEq(initialOrdersByPrice_.length, ordersByPrice_.length + 1);
            assertTrue(_isInArray(initialOrdersByPrice_, price_));
            assertFalse(_isInArray(ordersByPrice_, price_));
        }
    }

    function _removeSellLimitOrder(address user_, uint128 price_, uint48 orderId_) internal {
        price_ = price_ * dexBook.pricePrecision();
        uint256 initialDexBookEthBalance_ = eth.balanceOf(address(dexBook));
        uint256 initialUserEthBalance_ = eth.balanceOf(user_);

        LibPriceBrackets.OrdersByPrice[] memory initialOrdersByPrice_ = dexBook.sellOrdersAndPrices();

        uint256 usdcAmount_ = dexBook.sellOrderAtPrice(price_, orderId_).amount;
        uint256 ethAmount_ = _usdcToEth(usdcAmount_, price_);

        vm.prank(user_);
        dexBook.removeSellLimitOrder(orderId_, price_);

        assertApproxEq(eth.balanceOf(address(dexBook)), initialDexBookEthBalance_ - ethAmount_);
        assertApproxEq(eth.balanceOf(user_), initialUserEthBalance_ + ethAmount_);

        LibPriceBrackets.OrdersByPrice[] memory ordersByPrice_ = dexBook.sellOrdersAndPrices();

        assertTrue(_arePricesOrdered(initialOrdersByPrice_));
        assertTrue(_arePricesOrdered(ordersByPrice_));

        if (_isInArray(initialOrdersByPrice_, price_) && _isInArray(ordersByPrice_, price_)) {
            assertTrue(_compareArrays(initialOrdersByPrice_, ordersByPrice_));
        } else {
            assertEq(initialOrdersByPrice_.length, ordersByPrice_.length + 1);
            assertTrue(_isInArray(initialOrdersByPrice_, price_));
            assertFalse(_isInArray(ordersByPrice_, price_));
        }
    }

    function _increaseBuyLimitOrderAmountAndIncreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceIncrease_,
        uint256 ethIncrease_
    ) internal {
        uint128 newPrice_ = dexBook.pricePrecision() / (price_ + priceIncrease_);
        price_ = dexBook.pricePrecision() / price_;
        uint256 ethAmount_ = dexBook.buyOrderAtPrice(price_, orderId_).amount;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, dexBook.pricePrecision() ** 2 / price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ + ethIncrease_, dexBook.pricePrecision() ** 2 / newPrice_);
        _modifyAndAssertBuyLimitOrder(
            user_, orderId_, usdcAmount_, newUsdcAmount_, price_, newPrice_, ethAmount_ + ethIncrease_
        );
    }

    function _increaseBuyLimitOrderAmountAndDecreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceDecrease_,
        uint256 ethIncrease_
    ) internal {
        uint128 newPrice_ = dexBook.pricePrecision() / (price_ - priceDecrease_);
        price_ = dexBook.pricePrecision() / price_;
        uint256 ethAmount_ = dexBook.buyOrderAtPrice(price_, orderId_).amount;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, dexBook.pricePrecision() ** 2 / price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ + ethIncrease_, dexBook.pricePrecision() ** 2 / newPrice_);
        _modifyAndAssertBuyLimitOrder(
            user_, orderId_, usdcAmount_, newUsdcAmount_, price_, newPrice_, ethAmount_ + ethIncrease_
        );
    }

    function _decreaseBuyLimitOrderAmountAndIncreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceIncrease_,
        uint256 ethDecrease_
    ) internal {
        uint128 newPrice_ = dexBook.pricePrecision() / (price_ + priceIncrease_);
        price_ = dexBook.pricePrecision() / price_;
        uint256 ethAmount_ = dexBook.buyOrderAtPrice(price_, orderId_).amount;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, dexBook.pricePrecision() ** 2 / price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ - ethDecrease_, dexBook.pricePrecision() ** 2 / newPrice_);
        _modifyAndAssertBuyLimitOrder(
            user_, orderId_, usdcAmount_, newUsdcAmount_, price_, newPrice_, ethAmount_ - ethDecrease_
        );
    }

    function _decreaseBuyLimitOrderAmountAndDecreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceDecrease_,
        uint256 ethDecrease_
    ) internal {
        uint128 newPrice_ = dexBook.pricePrecision() / (price_ - priceDecrease_);
        price_ = dexBook.pricePrecision() / price_;
        uint256 ethAmount_ = dexBook.buyOrderAtPrice(price_, orderId_).amount;
        uint256 usdcAmount_ = _ethToUsdc(ethAmount_, dexBook.pricePrecision() ** 2 / price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ - ethDecrease_, dexBook.pricePrecision() ** 2 / newPrice_);
        _modifyAndAssertBuyLimitOrder(
            user_, orderId_, usdcAmount_, newUsdcAmount_, price_, newPrice_, ethAmount_ - ethDecrease_
        );
    }

    function _modifyAndAssertBuyLimitOrder(
        address user_,
        uint48 orderId_,
        uint256 usdcAmount_,
        uint256 newUsdcAmount_,
        uint128 price_,
        uint128 newPrice_,
        uint256 newEthAmount_
    ) internal {
        uint256 initialDexBookUsdcBalance_ = usdc.balanceOf(address(dexBook));
        uint256 initialUserUsdcBalance_ = usdc.balanceOf(user_);

        if (newUsdcAmount_ > usdcAmount_) {
            uint256 usdcIncrease_ = newUsdcAmount_ - usdcAmount_;
            initialUserUsdcBalance_ += usdcIncrease_;
            deal(address(usdc), user_, initialUserUsdcBalance_);
            vm.startPrank(user_);
            usdc.approve(address(dexBook), newUsdcAmount_ - usdcAmount_);
            uint48 newOrderId_ = dexBook.modifyBuyLimitOrder(
                orderId_, price_, newPrice_, newEthAmount_, new uint128[](1), new uint128[](1)
            );
            vm.stopPrank();

            assertApproxEq(usdc.balanceOf(address(dexBook)), initialDexBookUsdcBalance_ + usdcIncrease_);
            assertApproxEq(usdc.balanceOf(user_), initialUserUsdcBalance_ - usdcIncrease_);

            if (price_ != newPrice_) assertEq(dexBook.buyOrderAtPrice(price_, orderId_).amount, 0);
            assertApproxEq(dexBook.buyOrderAtPrice(newPrice_, newOrderId_).amount, newEthAmount_);
        } else {
            uint256 usdcDecrease_ = usdcAmount_ - newUsdcAmount_;
            vm.prank(user_);
            uint48 newOrderId_ = dexBook.modifyBuyLimitOrder(
                orderId_, price_, newPrice_, newEthAmount_, new uint128[](1), new uint128[](1)
            );

            assertApproxEq(usdc.balanceOf(address(dexBook)), initialDexBookUsdcBalance_ - usdcDecrease_);
            assertApproxEq(usdc.balanceOf(user_), initialUserUsdcBalance_ + usdcDecrease_);

            if (price_ != newPrice_) assertEq(dexBook.buyOrderAtPrice(price_, orderId_).amount, 0);
            assertApproxEq(dexBook.buyOrderAtPrice(newPrice_, newOrderId_).amount, newEthAmount_);
        }
    }

    function _increaseSellLimitOrderAmountAndIncreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceIncrease_,
        uint256 ethIncrease_
    ) internal {
        uint128 newPrice_ = (price_ + priceIncrease_) * dexBook.pricePrecision();
        price_ = price_ * dexBook.pricePrecision();
        uint256 usdcAmount_ = dexBook.sellOrderAtPrice(price_, orderId_).amount;
        uint256 ethAmount_ = _usdcToEth(usdcAmount_, price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ + ethIncrease_, newPrice_);
        uint256 newEthAmount_ = _usdcToEth(newUsdcAmount_, newPrice_);
        _modifyAndAssertSellLimitOrder(user_, orderId_, ethAmount_, newEthAmount_, price_, newPrice_, newUsdcAmount_);
    }

    function _increaseSellLimitOrderAmountAndDecreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceDecrease_,
        uint256 ethIncrease_
    ) internal {
        uint128 newPrice_ = (price_ - priceDecrease_) * dexBook.pricePrecision();
        price_ = price_ * dexBook.pricePrecision();
        uint256 usdcAmount_ = dexBook.sellOrderAtPrice(price_, orderId_).amount;
        uint256 ethAmount_ = _usdcToEth(usdcAmount_, price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ + ethIncrease_, newPrice_);
        uint256 newEthAmount_ = _usdcToEth(newUsdcAmount_, newPrice_);
        _modifyAndAssertSellLimitOrder(user_, orderId_, ethAmount_, newEthAmount_, price_, newPrice_, newUsdcAmount_);
    }

    function _decreaseSellLimitOrderAmountAndIncreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceIncrease_,
        uint256 ethDecrease
    ) internal {
        uint128 newPrice_ = (price_ + priceIncrease_) * dexBook.pricePrecision();
        price_ = price_ * dexBook.pricePrecision();
        uint256 usdcAmount_ = dexBook.sellOrderAtPrice(price_, orderId_).amount;
        uint256 ethAmount_ = _usdcToEth(usdcAmount_, price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ - ethDecrease, newPrice_);
        uint256 newEthAmount_ = _usdcToEth(newUsdcAmount_, newPrice_);
        _modifyAndAssertSellLimitOrder(user_, orderId_, ethAmount_, newEthAmount_, price_, newPrice_, newUsdcAmount_);
    }

    function _decreaseSellLimitOrderAmountAndDecreasePrice(
        address user_,
        uint48 orderId_,
        uint128 price_,
        uint128 priceDecrease_,
        uint256 ethDecrease
    ) internal {
        uint128 newPrice_ = (price_ - priceDecrease_) * dexBook.pricePrecision();
        price_ = price_ * dexBook.pricePrecision();
        uint256 usdcAmount_ = dexBook.sellOrderAtPrice(price_, orderId_).amount;
        uint256 ethAmount_ = _usdcToEth(usdcAmount_, price_);
        uint256 newUsdcAmount_ = _ethToUsdc(ethAmount_ - ethDecrease, newPrice_);
        uint256 newEthAmount_ = _usdcToEth(newUsdcAmount_, newPrice_);
        _modifyAndAssertSellLimitOrder(user_, orderId_, ethAmount_, newEthAmount_, price_, newPrice_, newUsdcAmount_);
    }

    function _modifyAndAssertSellLimitOrder(
        address user_,
        uint48 orderId_,
        uint256 ethAmount_,
        uint256 newEthAmount_,
        uint128 price_,
        uint128 newPrice_,
        uint256 newUsdcAmount_
    ) internal {
        uint256 initialDexBookEthBalance_ = eth.balanceOf(address(dexBook));
        uint256 initialUserEthBalance_ = eth.balanceOf(user_);

        if (newEthAmount_ > ethAmount_) {
            initialUserEthBalance_ += newEthAmount_ - ethAmount_;
            deal(address(eth), user_, initialUserEthBalance_);
            vm.startPrank(user_);
            eth.approve(address(dexBook), newEthAmount_ - ethAmount_);
            uint48 newOrderId_ = dexBook.modifySellLimitOrder(
                orderId_, price_, newPrice_, newUsdcAmount_, new uint128[](1), new uint128[](1)
            );
            vm.stopPrank();

            assertApproxEq(eth.balanceOf(address(dexBook)), initialDexBookEthBalance_ + newEthAmount_ - ethAmount_);
            assertApproxEq(eth.balanceOf(user_), initialUserEthBalance_ + ethAmount_ - newEthAmount_);

            if (price_ != newPrice_) assertEq(dexBook.sellOrderAtPrice(price_, orderId_).amount, 0);
            assertApproxEq(dexBook.sellOrderAtPrice(newPrice_, newOrderId_).amount, newUsdcAmount_);
        } else {
            vm.prank(user_);
            uint48 newOrderId_ = dexBook.modifySellLimitOrder(
                orderId_, price_, newPrice_, newUsdcAmount_, new uint128[](1), new uint128[](1)
            );

            assertApproxEq(eth.balanceOf(address(dexBook)), initialDexBookEthBalance_ + newEthAmount_ - ethAmount_);
            assertApproxEq(eth.balanceOf(user_), initialUserEthBalance_ + ethAmount_ - newEthAmount_);

            if (price_ != newPrice_) assertEq(dexBook.sellOrderAtPrice(price_, orderId_).amount, 0);
            assertApproxEq(dexBook.sellOrderAtPrice(newPrice_, newOrderId_).amount, newUsdcAmount_);
        }
    }

    function assertApproxEq(uint256 a_, uint256 b_) internal {
        if (a_ == b_) return;

        assertGt(a_, b_ * 999_999 / 1_000_000);
    }

    function _arePricesOrdered(LibPriceBrackets.OrdersByPrice[] memory prices_) internal pure returns (bool) {
        for (uint256 i_ = 1; i_ < prices_.length; i_++) {
            if (prices_[i_ - 1].price >= prices_[i_].price) {
                return false;
            }
        }
        return true;
    }

    function _compareArrays(
        LibPriceBrackets.OrdersByPrice[] memory array1_,
        LibPriceBrackets.OrdersByPrice[] memory array2_
    ) internal pure returns (bool) {
        if (array1_.length != array2_.length) return false;
        for (uint256 i = 0; i < array1_.length; i++) {
            if (array1_[i].price != array2_[i].price) return false;
        }
        return true;
    }

    function _isInArray(LibPriceBrackets.OrdersByPrice[] memory array_, uint128 value_) internal pure returns (bool) {
        for (uint256 i = 0; i < array_.length; i++) {
            if (array_[i].price == value_) {
                return true;
            }
        }
        return false;
    }

    function _amountPlusFee(uint256 amount) internal view returns (uint256) {
        return amount + _feeAmount(amount);
    }

    function _feeAmount(uint256 amount) internal view returns (uint256) {
        return amount * dexBook.protocolFee() / 10_000;
    }

    function _ethToUsdc(uint256 amount_, uint128 price_) internal pure returns (uint256) {
        return amount_ * price_ * 1e6 / 1e18 / 1e18;
    }

    function _ethToUsdcNoPrecision(uint256 amount_, uint128 price_) internal pure returns (uint256) {
        return amount_ * price_ * 1e6 / 1e18;
    }

    function _usdcToEth(uint256 amount_, uint128 price_) internal pure returns (uint256) {
        return amount_ * 1e18 * 1e18 / 1e6 / price_;
    }

    function _invertPrice(uint128 price_) internal pure returns (uint128) {
        return 1e36 / price_;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.17;

import {Test, stdError} from "forge-std/Test.sol";

import "../../../../../contracts/EVault/shared/types/Types.sol";

contract FeesFuzzTest is Test {
    using TypesLib for uint256;

    //positive tests

    function test_toFees(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_SMALL_AMOUNT);

        Fees fee = amount.toFees();

        assertEq(fee.toUint(), amount);
    }

    function test_addFees(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_SMALL_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_SMALL_AMOUNT);
        vm.assume(amount1 + amount2 <= MAX_SANE_SMALL_AMOUNT);

        uint256 result = amount1 + amount2;

        Fees fee1 = amount1.toFees();
        Fees fee2 = amount2.toFees();

        Fees resultFee = fee1 + fee2;

        assertEq(resultFee.toUint(), result);
    }

    function test_toShares(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_SMALL_AMOUNT);

        Fees fee = amount.toFees();

        Shares shares = amount.toShares();

        Shares resultShares = fee.toShares();

        assertEq(resultShares.toUint(), shares.toUint());
    }

    function test_mulDiv(uint256 amount, uint256 multiplier, uint256 divisor) public {
        vm.assume(amount <= MAX_SANE_SMALL_AMOUNT);
        vm.assume(multiplier <= uint256(MAX_SANE_SMALL_AMOUNT) / (amount + 1));
        vm.assume(divisor != 0 && divisor <= type(uint96).max);

        Fees fee = amount.toFees();

        Fees resultFee = fee.mulDiv(multiplier, divisor);

        uint256 result = amount * multiplier / divisor;

        assertEq(resultFee.toUint(), result);
    }

    function test_toAssetsDown(uint256 amount, uint256 _poolSize, uint256 _totalBorrows, uint256 _totalBalances)
        public
        pure
    {
        vm.assume(amount <= type(uint96).max - 1);
        vm.assume(_poolSize <= type(uint112).max - 1);
        vm.assume(_totalBorrows <= type(uint144).max);
        vm.assume(_totalBalances <= type(uint112).max - 1);

        MarketCache memory cache;
        cache.poolSize = _poolSize.toAssets();
        cache.totalBalances = _totalBalances.toShares();
        cache.totalBorrows = _totalBorrows.toOwed();

        (uint256 tA,) = totals(cache);
        vm.assume(tA <= type(uint112).max / (amount + 1));

        Fees fee = amount.toFees();

        fee.toAssetsDown(cache);
    }

    //negative tests

    function test_RevertWhenOverflowFee_toFees(uint256 amount) public {
        vm.assume(amount > MAX_SANE_SMALL_AMOUNT);

        vm.expectRevert(Errors.E_SmallAmountTooLargeToEncode.selector);

        amount.toFees();
    }

    function test_RevertWhenOverflowFee_addFees() public {
        uint256 amount = (type(uint96).max) / 2 + 1;

        Fees fee = amount.toFees();

        vm.expectRevert(Errors.E_SmallAmountTooLargeToEncode.selector);

        fee + fee;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.17;

import {Test, stdError} from "forge-std/Test.sol";

import "../../../../../contracts/EVault/shared/types/Types.sol";

contract SharesFuzzTest is Test {
    using TypesLib for uint256;

    //positive tests

    function test_toShares(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_AMOUNT);

        Shares shares = amount.toShares();

        assertEq(shares.toUint(), amount);
    }

    function test_addShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);
        vm.assume(amount1 + amount2 <= MAX_SANE_AMOUNT);

        uint256 result = amount1 + amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        Shares resultShares = shares1 + shares2;

        assertEq(resultShares.toUint(), result);
    }

    function test_subShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);
        vm.assume(amount1 >= amount2);

        uint256 result = amount1 - amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        Shares resultShares = shares1 - shares2;

        assertEq(resultShares.toUint(), result);
    }

    function test_eqShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 == amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        bool resultEq = shares1 == shares2;

        assertEq(resultEq, result);
    }

    function test_neqShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 != amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        bool resultNeq = shares1 != shares2;

        assertEq(resultNeq, result);
    }

    function test_gtShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 > amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        bool resultGt = shares1 > shares2;

        assertEq(resultGt, result);
    }

    function test_ltShares(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 > amount2;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        bool resultLt = shares1 > shares2;

        assertEq(resultLt, result);
    }

    function test_isZero(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_AMOUNT);

        Shares shares = amount.toShares();

        bool result = shares.isZero();

        assertEq(result, amount == 0);
    }

    function test_toAssetsDown(uint256 amount, uint256 _poolSize, uint256 _totalBorrows, uint256 _totalBalances)
        public
        pure
    {
        vm.assume(amount <= type(uint112).max - 1);
        vm.assume(_poolSize <= type(uint112).max - 1);
        vm.assume(_totalBalances <= type(uint112).max - 1);
        vm.assume(_totalBorrows <= type(uint144).max);

        MarketCache memory cache;
        cache.poolSize = _poolSize.toAssets();
        cache.totalBalances = _totalBalances.toShares();
        cache.totalBorrows = _totalBorrows.toOwed();

        (uint256 tA,) = totals(cache);
        vm.assume(tA <= type(uint112).max / (amount + 1));

        Shares shares = amount.toShares();

        shares.toAssetsDown(cache);
    }

    function test_toAssetsUp(uint256 amount, uint256 _poolSize, uint256 _totalBorrows, uint256 _totalBalances)
        public
        pure
    {
        vm.assume(amount <= type(uint112).max - 1);
        vm.assume(_poolSize <= type(uint112).max - 1);
        vm.assume(_totalBalances <= type(uint112).max - 1);
        vm.assume(_totalBorrows <= type(uint144).max);

        MarketCache memory cache;
        cache.poolSize = _poolSize.toAssets();
        cache.totalBorrows = _totalBorrows.toOwed();
        cache.totalBalances = _totalBalances.toShares();

        (uint256 tA,) = totals(cache);
        vm.assume(tA <= type(uint112).max / (amount + 1));

        Shares shares = amount.toShares();

        shares.toAssetsUp(cache);
    }

    //negative tests

    function test_RevertWhenOverflowShares_toShares(uint256 amount) public {
        vm.assume(amount > MAX_SANE_AMOUNT);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);

        amount.toShares();
    }

    function test_RevertWhenOverflowShares_addShares() public {
        uint256 amount = (type(uint112).max) / 2 + 1;

        Shares shares = amount.toShares();

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        shares + shares;
    }

    function test_RevertWhenUnderflowShare_subShares() public {
        uint256 amount1 = 0;
        uint256 amount2 = 1;

        Shares shares1 = amount1.toShares();
        Shares shares2 = amount2.toShares();

        vm.expectRevert(stdError.arithmeticError);
        shares1 - shares2;
    }
}

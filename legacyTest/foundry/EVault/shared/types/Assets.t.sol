// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import "../../../../../contracts/EVault/shared/types/Assets.sol";
import "../../../../../contracts/EVault/shared/Errors.sol";

contract AssetsFuzzTest is Test {
    using TypesLib for uint256;

    //positive tests

    function test_toAssets(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_AMOUNT);

        Assets asset = amount.toAssets();

        assertEq(asset.toUint(), amount);
    }

    function test_addAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);
        vm.assume(amount1 + amount2 <= MAX_SANE_AMOUNT);

        uint256 result = amount1 + amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        Assets resultAsset = asset1 + asset2;

        assertEq(resultAsset.toUint(), result);
    }

    function test_subAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);
        vm.assume(amount1 >= amount2);

        uint256 result = amount1 - amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        Assets resultAsset = asset1 - asset2;

        assertEq(resultAsset.toUint(), result);
    }

    function test_eqAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 == amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        bool resultAsset = asset1 == asset2;

        assertEq(resultAsset, result);
    }

    function test_neqAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 != amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        bool resultAsset = asset1 != asset2;

        assertEq(resultAsset, result);
    }

    function test_gtAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 > amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        bool resultAsset = asset1 > asset2;

        assertEq(resultAsset, result);
    }

    function test_ltAssets(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 <= MAX_SANE_AMOUNT);
        vm.assume(amount2 <= MAX_SANE_AMOUNT);

        bool result = amount1 > amount2;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        bool resultAsset = asset1 > asset2;

        assertEq(resultAsset, result);
    }

    function test_isZero(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_AMOUNT);

        Assets asset = amount.toAssets();

        bool result = asset.isZero();

        assertEq(result, amount == 0);
    }

    function test_toOwed(uint256 amount) public {
        vm.assume(amount <= MAX_SANE_AMOUNT);

        Assets assets = amount.toAssets();

        Owed owed = amount.toOwed();

        Owed resultOwed = assets.toOwed();

        assertEq(resultOwed.toUint(), owed.toUint() * INTERNAL_DEBT_PRECISION);
    }

    function test_toSharesDown(uint256 amount, uint256 _poolSize, uint256 _totalBorrows, uint256 _totalBalances)
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

        (, uint256 tB) = totals(cache);
        vm.assume(tB <= type(uint112).max / (amount + 1));

        Assets assets = amount.toAssets();

        assets.toSharesDown(cache);
    }

    function test_toSharesUp(uint256 amount, uint256 _poolSize, uint256 _totalBorrows, uint256 _totalBalances)
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

        (, uint256 tB) = totals(cache);
        vm.assume(tB <= type(uint112).max / (amount + 1));

        Assets assets = amount.toAssets();

        assets.toSharesUp(cache);
    }

    //negative tests

    function test_RevertWhenOverflowAsset_toAssets(uint256 amount) public {
        vm.assume(amount > MAX_SANE_AMOUNT);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);

        amount.toAssets();
    }

    function test_RevertWhenOverflowAsset_addAssets() public {
        uint256 amount = (type(uint112).max) / 2 + 1;

        Assets asset = amount.toAssets();

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        asset + asset;
    }

    function test_RevertWhenUnderflowAsset_subAssets() public {
        uint256 amount1 = 0;
        uint256 amount2 = 1;

        Assets asset1 = amount1.toAssets();
        Assets asset2 = amount2.toAssets();

        vm.expectRevert(stdError.arithmeticError);
        asset1 - asset2;
    }
}

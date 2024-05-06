// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVaultTestBase.t.sol";
import {EVault} from "src/EVault/EVault.sol";

import "src/EVault/shared/types/Types.sol";

contract EVaultHarness is EVault {
    using TypesLib for uint256;

    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    function setCash_(uint256 value) public {
        vaultStorage.cash = Assets.wrap(uint112(value));
    }

    function setTotalBorrow_(uint256 value) public {
        vaultStorage.totalBorrows = Owed.wrap(uint144(value));
    }

    function setTotalShares_(uint256 value) public {
        vaultStorage.totalShares = Shares.wrap(uint112(value));
    }
}

contract VaultTest_Conversion is EVaultTestBase {
    address user1;

    EVaultHarness public eTST0;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");

        address evaultImpl = address(new EVaultHarness(integrations, modules));
        vm.prank(admin);
        factory.setImplementation(evaultImpl);

        eTST0 = EVaultHarness(coreProductLine.createVault(address(assetTST), address(oracle), unitOfAccount));
        eTST0.setInterestRateModel(address(new IRMTestDefault()));
    }

    function testFuzz_convertToAssets_previewReedem(uint256 cash, uint256 shares, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT);
        cash = bound(cash, deposit, MAX_SANE_AMOUNT);
        shares = bound(shares, cash, MAX_SANE_AMOUNT);

        startHoax(user1);
        assetTST.mint(user1, deposit);
        assetTST.mint(address(eTST0), type(uint256).max - deposit);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.deposit(deposit, user1);

        startHoax(address(this));
        eTST0.setCash_(cash);
        eTST0.setTotalShares_(shares);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);

        uint256 predictedAssets = eTST0.previewRedeem(deposit);
        assertEq(eTST0.convertToAssets(deposit), predictedAssets);

        startHoax(user1);
        if (predictedAssets == 0) {
            vm.expectRevert(Errors.E_ZeroAssets.selector);
            eTST0.redeem(deposit, user1, user1);
            return;
        }

        eTST0.redeem(deposit, user1, user1);
        assertEq(assetTST.balanceOf(user1), predictedAssets);
    }

    function testFuzz_previewWithdraw(uint256 cash, uint256 shares, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT);
        cash = bound(cash, deposit, MAX_SANE_AMOUNT);
        shares = bound(shares, cash, MAX_SANE_AMOUNT);

        startHoax(user1);
        assetTST.mint(user1, deposit);
        assetTST.mint(address(eTST0), type(uint256).max - deposit);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.deposit(deposit, user1);

        startHoax(address(this));
        eTST0.setCash_(cash);
        eTST0.setTotalShares_(shares);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);

        uint256 predictedValue = eTST0.previewWithdraw(deposit);

        uint256 maxValue = eTST0.maxWithdraw(user1);

        startHoax(user1);
        if (maxValue < deposit) {
            vm.expectRevert(Errors.E_InsufficientBalance.selector);
            eTST0.withdraw(deposit, user1, user1);
            return;
        }

        uint256 resultValue = eTST0.withdraw(deposit, user1, user1);
        assertEq(resultValue, predictedValue);
    }

    function testFuzz_maxWithdraw(uint256 cash, uint256 shares, uint256 borrows, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT);
        cash = bound(cash, deposit, MAX_SANE_AMOUNT);
        borrows = bound(borrows, 0, MAX_SANE_AMOUNT);
        vm.assume(cash + borrows <= MAX_SANE_AMOUNT);
        shares = bound(shares, cash + borrows, MAX_SANE_AMOUNT);

        startHoax(user1);
        assetTST.mint(user1, deposit);
        assetTST.mint(address(eTST0), type(uint256).max - deposit);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.deposit(deposit, user1);

        startHoax(address(this));
        eTST0.setTotalShares_(shares);
        eTST0.setTotalBorrow_(borrows);
        eTST0.setCash_(cash);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);
        assertEq(eTST0.totalBorrowsExact(), borrows);

        uint256 maxAssets = eTST0.maxWithdraw(user1);

        uint256 snapshot = vm.snapshot();

        startHoax(user1);
        eTST0.withdraw(maxAssets, user1, user1);
        assertEq(assetTST.balanceOf(user1), maxAssets);

        vm.revertTo(snapshot);

        if (maxAssets >= eTST0.cash()) {
            vm.expectRevert(Errors.E_InsufficientCash.selector);
            eTST0.withdraw(maxAssets + 1, user1, user1);
            return;
        }

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        eTST0.withdraw(maxAssets + 1, user1, user1);
    }

    function testFuzz_convertToShares_previewDeposit(uint256 cash, uint256 shares, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT / 2);
        cash = bound(cash, deposit, MAX_SANE_AMOUNT / 2);
        shares = bound(shares, cash, MAX_SANE_AMOUNT / 2);

        startHoax(address(this));
        eTST0.setTotalShares_(shares);
        eTST0.setCash_(cash);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);
        assertEq(eTST0.balanceOf(user1), 0);

        uint256 predictedShares = eTST0.previewDeposit(deposit);
        assertEq(eTST0.convertToShares(deposit), predictedShares);

        startHoax(user1);
        assetTST.mint(user1, deposit);
        assetTST.approve(address(eTST0), type(uint256).max);

        uint256 resultShares = eTST0.deposit(deposit, user1);

        assertEq(resultShares, predictedShares);
        assertEq(eTST0.balanceOf(user1), predictedShares);
    }

    function testFuzz_maxDeposit(uint256 cash) public {
        cash = bound(cash, 1, MAX_SANE_AMOUNT);

        startHoax(address(this));
        eTST0.setCash_(cash);
        eTST0.setTotalShares_(cash);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), cash);

        uint256 maxAssets = eTST0.maxDeposit(user1);

        startHoax(user1);
        assetTST.mint(user1, type(uint256).max);
        assetTST.approve(address(eTST0), type(uint256).max);

        uint256 snapshot = vm.snapshot();

        eTST0.deposit(maxAssets, user1);

        vm.revertTo(snapshot);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.deposit(maxAssets + 1, user1);
    }

    function testFuzz_maxMint(uint256 cash) public {
        cash = bound(cash, 1, MAX_SANE_AMOUNT);

        startHoax(address(this));
        eTST0.setTotalShares_(cash);
        eTST0.setCash_(cash);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), cash);

        uint256 maxShares = eTST0.maxMint(user1);

        startHoax(user1);
        assetTST.mint(user1, type(uint256).max);
        assetTST.approve(address(eTST0), type(uint256).max);

        uint256 snapshot = vm.snapshot();

        eTST0.mint(maxShares, user1);

        vm.revertTo(snapshot);

        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        eTST0.mint(maxShares + 1, user1);
    }

    function testFuzz_previewMint(uint256 cash, uint256 shares, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT / 2);
        shares = bound(shares, deposit, MAX_SANE_AMOUNT / 2);
        cash = bound(cash, deposit, shares);

        startHoax(address(this));
        eTST0.setTotalShares_(shares);
        eTST0.setCash_(cash);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);
        assertEq(eTST0.balanceOf(user1), 0);

        uint256 predictedAssets = eTST0.previewMint(deposit);

        startHoax(user1);
        assetTST.mint(user1, type(uint256).max);
        assetTST.approve(address(eTST0), type(uint256).max);

        uint256 resultAssets = eTST0.mint(deposit, user1);
        assertEq(resultAssets, predictedAssets);

        uint256 spentAssets = type(uint256).max - assetTST.balanceOf(user1);
        assertEq(spentAssets, predictedAssets);

        assertEq(eTST0.balanceOf(user1), deposit);
    }

    function testFuzz_maxRedeem(uint256 cash, uint256 shares, uint256 deposit) public {
        deposit = bound(deposit, 1, MAX_SANE_AMOUNT - 1);
        cash = bound(cash, deposit, MAX_SANE_AMOUNT);
        shares = bound(shares, cash, MAX_SANE_AMOUNT);

        startHoax(user1);
        assetTST.mint(user1, deposit);
        assetTST.mint(address(eTST0), type(uint256).max - deposit);
        assetTST.approve(address(eTST0), type(uint256).max);
        eTST0.deposit(deposit, user1);

        startHoax(address(this));
        eTST0.setCash_(cash);
        eTST0.setTotalShares_(shares);

        assertEq(eTST0.cash(), cash);
        assertEq(eTST0.totalSupply(), shares);
        assertEq(eTST0.balanceOf(user1), deposit);

        uint256 maxValue = eTST0.maxRedeem(user1);

        uint256 predictedAssets = eTST0.convertToAssets(maxValue);

        startHoax(user1);

        if (predictedAssets == 0) {
            vm.expectRevert(Errors.E_ZeroAssets.selector);
            eTST0.redeem(maxValue, user1, user1);
            return;
        }

        uint256 snapshot = vm.snapshot();

        eTST0.redeem(maxValue, user1, user1);

        vm.revertTo(snapshot);

        if (predictedAssets >= eTST0.cash()) {
            vm.expectRevert(Errors.E_InsufficientCash.selector);
            eTST0.redeem(maxValue + 1, user1, user1);
            return;
        }

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        eTST0.redeem(maxValue + 1, user1, user1);
    }
}

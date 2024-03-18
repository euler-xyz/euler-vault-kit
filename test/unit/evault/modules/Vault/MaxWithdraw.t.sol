// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";
import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract ERC4626Test_MaxWithdraw is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;
    address borrower2;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");
        borrower2 = makeAddr("borrower_2");

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);


        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);


        // Borrower

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);
    }


    function test_basicMaxWithdraw() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);

        uint256 maxWithdrawAmount = eTST2.maxWithdraw(borrower);
        uint256 expectedBurnedShares = eTST2.previewWithdraw(maxWithdrawAmount);

        uint256 assetBalanceBefore = assetTST2.balanceOf(borrower);
        uint256 eVaultSharesBalanceBefore = eTST2.balanceOf(borrower);

        // Should only be able to withdraw up to maxWithdraw, so these should fail:
        
        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST2.withdraw(maxWithdrawAmount + 1, borrower, borrower);

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST2.withdraw(maxWithdrawAmount + 1e18, borrower, borrower);

        // Withdrawing the maximum should pass
        eTST2.withdraw(maxWithdrawAmount, borrower, borrower);


        // Assert asset & eVault share balances change as expected
        uint256 assetBalanceAfter = assetTST2.balanceOf(borrower);
        uint256 eVaultSharesBalanceAfter = eTST2.balanceOf(borrower);

        assertEq(assetBalanceAfter - assetBalanceBefore, maxWithdrawAmount);
        assertEq(eVaultSharesBalanceBefore - eVaultSharesBalanceAfter, expectedBurnedShares);
    }

    function test_basicMaxRedeem() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);

        uint256 maxRedeemAmount = eTST2.maxRedeem(borrower);
        uint256 expectedRedeemedAssets = eTST2.previewRedeem(maxRedeemAmount);

        uint256 assetBalanceBefore = assetTST2.balanceOf(borrower);
        uint256 eVaultSharesBalanceBefore = eTST2.balanceOf(borrower);

        // Should only be able to redeem up to maxRedeem, so these should fail:

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST2.redeem(maxRedeemAmount + 1, borrower, borrower);

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST2.redeem(maxRedeemAmount + 1e18, borrower, borrower);

        // Withdrawing the maximum should pass
        eTST2.redeem(maxRedeemAmount, borrower, borrower);

        // Assert asset & eVault share balances change as expected
        uint256 assetBalanceAfter = assetTST2.balanceOf(borrower);
        uint256 eVaultSharesBalanceAfter = eTST2.balanceOf(borrower);

        assertEq(assetBalanceAfter - assetBalanceBefore, expectedRedeemedAssets);
        assertEq(eVaultSharesBalanceBefore - eVaultSharesBalanceAfter, maxRedeemAmount);
    }
}

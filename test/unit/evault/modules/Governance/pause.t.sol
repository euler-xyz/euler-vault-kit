// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase, EthereumVaultConnector} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import "src/EVault/shared/Constants.sol";
import "src/EVault/shared/types/Types.sol";

// If this address is installed, it should be able to set disabled ops
// Use a different address than the governor
// The pauseGuardian() accessor should return the currently installed pause guardian
// After pausing, trying to invoke the disabled ops should fail
// The pause guardian should be able to re-enable the ops (unpause)
// After re-enabling, the ops should start working again

contract Governance_PauseAndOps is EVaultTestBase {
    address notGovernor;
    address borrower;
    address depositor;
    uint256 constant MINT_AMOUNT = 100e18;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");
        borrower = makeAddr("borrower");
        depositor = makeAddr("depositor");
        // ----------------- Setup depositor -----------------
        vm.startPrank(depositor);
        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(MINT_AMOUNT, depositor);
        vm.stopPrank();
        // ----------------- Setup borrower -----------------
        vm.startPrank(borrower);
        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(MINT_AMOUNT, borrower);
        vm.stopPrank();
    }

    function testFuzz_setDisabledOpsShouldFailIfNotGovernor(uint32 newDisabledOps) public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setDisabledOps(newDisabledOps);
    }

    function testFuzz_pauseGuardianShouldBeAbleToSetPauseGuardian(address newGovernor) public {
        eTST.setPauseGuardian(newGovernor);
        assertEq(eTST.pauseGuardian(), newGovernor);
    }

    function testFuzz_pauseGuardianShouldBeAbleToSetDisabledOps(uint32 newDisabledOps) public {
        eTST.setDisabledOps(newDisabledOps);
        assertEq(eTST.disabledOps(), newDisabledOps);
    }

    function testFuzz_disablingDepositOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_DEPOSIT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(amount, receiver);
    }

    function testFuzz_disablingMintOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_MINT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(amount, receiver);
    }

    function testFuzz_disablingWithdrawOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner)
        public
    {
        eTST.setDisabledOps(OP_WITHDRAW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.withdraw(amount, receiver, owner);
    }

    function testFuzz_disablingRedeemOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner)
        public
    {
        eTST.setDisabledOps(OP_REDEEM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(amount, receiver, owner);
    }

    function testFuzz_disablingTransferOpsShouldFailAfterDisabled(address to, uint256 amount) public {
        eTST.setDisabledOps(OP_TRANSFER);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.transfer(to, amount);
    }

    function testFuzz_skimmingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_SKIM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.skim(amount, receiver);
    }

    function testFuzz_borrowingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_BORROW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.borrow(amount, receiver);
    }

    function testFuzz_repayingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_REPAY);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.repay(amount, receiver);
    }

    function testFuzz_loopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address sharesReceiver) public {
        eTST.setDisabledOps(OP_LOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.loop(amount, sharesReceiver);
    }

    function testFuzz_deloopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address debtFrom) public {
        eTST.setDisabledOps(OP_DELOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deloop(amount, debtFrom);
    }

    function testFuzz_pullingDebtDisabledOpsShouldFailAfterDisabled(uint256 amount, address from) public {
        eTST.setDisabledOps(OP_PULL_DEBT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.pullDebt(amount, from);
    }

    function testFuzz_convertingFeesDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_CONVERT_FEES);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.convertFees();
    }

    function testFuzz_liquidatingDisabledOpsShouldFailAfterDisabled(
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) public {
        eTST.setDisabledOps(OP_LIQUIDATE);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.liquidate(violator, collateral, repayAssets, minYieldBalance);
    }

    function testFuzz_flashLoanDisabledOpsShouldFailAfterDisabled(uint256 amount, bytes calldata data) public {
        eTST.setDisabledOps(OP_FLASHLOAN);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.flashLoan(amount, data);
    }

    function testFuzz_touchDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_TOUCH);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.touch();
    }

    // TODO: accrue interest is a little bit different
    // TODO: socialize debt is a little bit different

    function testFuzz_validateAssetsReceiverDisabledShouldFailBorrowAfterDisabled(uint256 amount, address receiver)
        public
    {
        amount = bound(amount, 1, MINT_AMOUNT);
        vm.assume(receiver != address(0));

        address subacc = address(uint160(borrower) >> 8 << 8);

        vm.startPrank(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));
        vm.expectRevert(Errors.E_BadAssetReceiver.selector); //! note this is a different error
        eTST.borrow(amount, subacc);
        vm.stopPrank();

        eTST.setDisabledOps(OP_VALIDATE_ASSET_RECEIVER);

        vm.startPrank(borrower);
        eTST.borrow(amount, receiver);
        vm.stopPrank();
    }
}

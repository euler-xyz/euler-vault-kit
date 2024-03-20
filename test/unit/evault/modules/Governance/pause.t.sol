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
    uint32[] allOps;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");
        allOps = [OP_DEPOSIT, OP_MINT, OP_WITHDRAW, OP_REDEEM, OP_TRANSFER];
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

    function test_disablingDepositOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_DEPOSIT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(amount, receiver);
    }

    function test_disablingMintOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_MINT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(amount, receiver);
    }

    function test_disablingWithdrawOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner) public {
        eTST.setDisabledOps(OP_WITHDRAW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.withdraw(amount, receiver, owner);
    }

    function test_disablingRedeemOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner) public {
        eTST.setDisabledOps(OP_REDEEM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(amount, receiver, owner);
    }

    function test_disablingTransferOpsShouldFailAfterDisabled(address to, uint256 amount) public {
        eTST.setDisabledOps(OP_TRANSFER);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.transfer(to, amount);
    }

    function test_skimmingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_SKIM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.skim(amount, receiver);
    }

    function test_borrowingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_BORROW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.borrow(amount, receiver);
    }

    function test_repayingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_REPAY);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.repay(amount, receiver);
    }

    function test_loopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address sharesReceiver) public {
        eTST.setDisabledOps(OP_LOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.loop(amount, sharesReceiver);
    }

    function test_deloopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address debtFrom) public {
        eTST.setDisabledOps(OP_DELOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deloop(amount, debtFrom);
    }

    function test_pullingDebtDisabledOpsShouldFailAfterDisabled(uint256 amount, address from) public {
        eTST.setDisabledOps(OP_PULL_DEBT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.pullDebt(amount, from);
    }

    function test_convertingFeesDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_CONVERT_FEES);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.convertFees();
    }

    function test_liquidatingDisabledOpsShouldFailAfterDisabled(
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) public {
        eTST.setDisabledOps(OP_LIQUIDATE);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.liquidate(violator, collateral, repayAssets, minYieldBalance);
    }

    function test_flashLoanDisabledOpsShouldFailAfterDisabled(uint256 amount, bytes calldata data) public {
        eTST.setDisabledOps(OP_FLASHLOAN);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.flashLoan(amount, data);
    }

    function test_touchDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_TOUCH);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.touch();
    }

    // TODO: accrue interest is a little bit different
    // TODO: socialize debt is a little bit different

    function test_validateAssetsReceiverDisabledShouldFailBorrowAfterDisabled(uint256 amount, address receiver)
        public
    {
        eTST.setDisabledOps(OP_VALIDATE_ASSET_RECEIVER);
        receiver = address(0);
        vm.mockCall(
            address(evc),
            abi.encodeWithSelector(EthereumVaultConnector.getCurrentOnBehalfOfAccount.selector, address(eTST)),
            abi.encode(true, true)
        );
        vm.expectRevert(Errors.E_BadAssetReceiver.selector); //! note this is a different error
        eTST.borrow(amount, receiver);
    }
}

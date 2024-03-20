// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import "src/EVault/shared/Constants.sol";

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

    function test_disablingDepositOPShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_DEPOSIT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(amount, receiver);
    }

    function test_disablingMintOPShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_MINT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(amount, receiver);
    }

    function test_disablingWithdrawOPShouldFailAfterDisabled(uint256 amount, address receiver, address owner) public {
        eTST.setDisabledOps(OP_WITHDRAW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.withdraw(amount, receiver, owner);
    }

    function test_disablingRedeemOPShouldFailAfterDisabled(uint256 amount, address receiver, address owner) public {
        eTST.setDisabledOps(OP_REDEEM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(amount, receiver, owner);
    }

    function test_disablingTransferOPShouldFailAfterDisabled(address to, uint256 amount) public {
        eTST.setDisabledOps(OP_TRANSFER);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.transfer(to, amount);
    }
}

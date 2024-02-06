// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "test/unit/evault/EVaultTestBase.t.sol";
import {Errors as EVCErrors} from "ethereum-vault-connector/Errors.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {Events} from "src/EVault/shared/Events.sol";

contract ERC20Test_Actions is EVaultTestBase {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_Transfer_Integrity(uint256 balance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.expectEmit();
        emit Events.Transfer(alice, bob, amount);
        vm.prank(alice);
        bool success = eTST.transfer(bob, amount);

        assertTrue(success);
        assertEq(eTST.balanceOf(alice), balance - amount);
        assertEq(eTST.balanceOf(bob), amount);
    }

    function test_Transfer_ZeroOk(uint256 balance) public {
        balance = bound(balance, 1, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.expectEmit();
        emit Events.Transfer(alice, bob, 0);
        vm.prank(alice);
        bool success = eTST.transfer(bob, 0);

        assertTrue(success);
        assertEq(eTST.balanceOf(alice), balance);
        assertEq(eTST.balanceOf(bob), 0);
    }

    function test_Transfer_BalanceForwarderEnabled(uint256 balance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.enableBalanceForwarder();
        vm.prank(bob);
        eTST.enableBalanceForwarder();

        vm.prank(alice);
        eTST.transfer(bob, amount);

        assertEq(MockBalanceTracker(balanceTracker).calls(alice, balance - amount, false), 1);
        assertEq(MockBalanceTracker(balanceTracker).calls(bob, amount, false), 1);
    }

    function test_Transfer_BalanceForwarderDisabled(uint256 balance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.transfer(bob, amount);

        assertFalse(eTST.balanceForwarderEnabled(alice));
        assertFalse(eTST.balanceForwarderEnabled(bob));
        assertEq(MockBalanceTracker(balanceTracker).numCalls(), 0);
    }

    function test_Transfer_RevertsWhen_InsufficientBalance(uint256 balance, uint256 amount) public {
        amount = bound(amount, 2, MAX_SANE_AMOUNT);
        balance = bound(balance, 1, amount - 1);

        _mintAndDeposit(alice, balance);

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        vm.prank(alice);
        eTST.transfer(bob, amount);
    }

    function test_Transfer_RevertsWhen_SelfTransfer(uint256 balance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.expectRevert(Errors.E_SelfTransfer.selector);
        vm.prank(alice);
        eTST.transfer(alice, amount);
    }

    function test_Transfer_RevertsWhen_ReentrancyThroughBalanceTracker() public {
        _mintAndDeposit(alice, 1 ether);

        vm.prank(alice);
        eTST.enableBalanceForwarder();

        MockBalanceTracker(balanceTracker).setReentrantCall(address(eTST), abi.encodeCall(eTST.transfer, (bob, 0.5 ether)));

        vm.expectRevert(Errors.E_Reentrancy.selector);
        vm.prank(alice);
        eTST.transfer(bob, 0.5 ether);
    }

    function test_TransferFrom_Integrity(uint256 balance, uint256 allowance, uint256 amount) public {
        // amount <= allowance <= balance
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        allowance = bound(allowance, amount, MAX_SANE_AMOUNT);
        balance = bound(balance, allowance, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.approve(bob, allowance);

        vm.expectEmit();
        emit Events.Transfer(alice, bob, amount);
        vm.prank(bob);
        bool success = eTST.transferFrom(alice, bob, amount);

        assertTrue(success);
        assertEq(eTST.balanceOf(alice), balance - amount);
        assertEq(eTST.balanceOf(bob), amount);
        assertEq(eTST.allowance(alice, bob), allowance - amount);
    }

    function test_TransferFrom_ZeroOk(uint256 balance, uint256 allowance) public {
        allowance = bound(allowance, 0, MAX_SANE_AMOUNT);
        balance = bound(balance, allowance, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.approve(bob, allowance);

        vm.expectEmit();
        emit Events.Transfer(alice, bob, 0);
        vm.prank(bob);
        bool success = eTST.transferFrom(alice, bob, 0);

        assertTrue(success);
        assertEq(eTST.balanceOf(alice), balance);
        assertEq(eTST.balanceOf(bob), 0);
        assertEq(eTST.allowance(alice, bob), allowance);
    }

    function test_TransferFrom_RevertsWhen_InsufficientBalance(uint256 balance, uint256 allowance, uint256 amount) public {
        amount = bound(amount, 2, MAX_SANE_AMOUNT);
        balance = bound(balance, 1, amount - 1);
        allowance = bound(allowance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.approve(bob, allowance);

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        vm.prank(bob);
        eTST.transferFrom(alice, bob, amount);
    }

    function test_TransferFrom_RevertsWhen_InsufficientAllowance(uint256 balance, uint256 allowance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);
        allowance = bound(allowance, 0, amount - 1);

        _mintAndDeposit(alice, balance);

        vm.prank(alice);
        eTST.approve(bob, allowance);

        vm.expectRevert(Errors.E_InsufficientAllowance.selector);
        vm.prank(bob);
        eTST.transferFrom(alice, bob, amount);
    }

    function test_TransferFrom_RevertsWhen_SelfTransfer(uint256 balance, uint256 amount) public {
        amount = bound(amount, 1, MAX_SANE_AMOUNT);
        balance = bound(balance, amount, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);

        vm.expectRevert(Errors.E_SelfTransfer.selector);
        vm.prank(alice);
        eTST.transferFrom(alice, alice, amount);
    }

    function test_TransferFromMax_Integrity(uint256 balance) public {
        balance = bound(balance, 1, MAX_SANE_AMOUNT);

        _mintAndDeposit(alice, balance);
        vm.prank(alice);
        eTST.approve(bob, balance);
        
        vm.prank(bob);
        bool success = eTST.transferFromMax(alice, bob);

        assertTrue(success);
        assertEq(eTST.balanceOf(alice), 0);
        assertEq(eTST.balanceOf(bob), balance);
    }

    function test_Approve_Integrity(uint256 allowance) public {
        vm.startPrank(alice);
        vm.expectEmit();
        emit Events.Approval(alice, bob, allowance);
        bool success = eTST.approve(bob, allowance);
        assertTrue(success);
        assertEq(eTST.allowance(alice, bob), allowance);
    }

    function test_Approve_Overwrite(uint256 allowanceA, uint256 allowanceB) public {
        vm.startPrank(alice);
        eTST.approve(bob, allowanceA);
        bool success = eTST.approve(bob, allowanceB);
        assertTrue(success);
        assertEq(eTST.allowance(alice, bob), allowanceB);
    }

    function test_Approve_EVCOnBehalfOf(uint256 allowance) public {
        vm.mockCall(address(evc), abi.encodeCall(evc.getCurrentOnBehalfOfAccount, (address(0))), abi.encode(alice, false));
        vm.prank(address(evc));
        bool success = eTST.approve(bob, allowance);
        assertTrue(success);
        assertEq(eTST.allowance(alice, bob), allowance);
    }

    function test_Approve_RevertsWhen_SelfApproval(uint256 allowance) public {
        vm.expectRevert(Errors.E_SelfApproval.selector);
        vm.prank(alice);
        eTST.approve(alice, allowance);
    }

    function test_Approve_RevertsWhen_EVCOnBehalfOfAccountNotAuthenticated(uint256 allowance) public {
        vm.expectRevert(EVCErrors.EVC_OnBehalfOfAccountNotAuthenticated.selector);
        vm.prank(address(evc));
        eTST.approve(alice, allowance);
    }

    function _mintAndDeposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        assetTST.mint(user, amount);
        assetTST.approve(address(eTST), amount);
        eTST.deposit(amount, user);
        vm.stopPrank();
    }
}

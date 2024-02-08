// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {Events} from "src/EVault/shared/Events.sol";

contract BalanceForwarderTest_Control is EVaultTestBase {
    address alice = makeAddr("alice");

    function test_BalanceTrackerAddress_Integrity() public {
        assertEq(eTST.balanceTrackerAddress(), balanceTracker);
    }

    function test_Enable() public {
        vm.expectEmit();
        emit Events.BalanceForwarderStatus(alice, true);
        vm.prank(alice);
        eTST.enableBalanceForwarder();

        assertTrue(eTST.balanceForwarderEnabled(alice));
        assertEq(MockBalanceTracker(balanceTracker).numCalls(), 1);
        assertEq(MockBalanceTracker(balanceTracker).calls(alice, 0, false), 1);
    }

    function test_Enable_EVCAuthenticate() public {
        vm.mockCall(address(evc), abi.encodeCall(evc.getCurrentOnBehalfOfAccount, (address(0))), abi.encode(alice, false));
        vm.prank(address(evc));
        eTST.enableBalanceForwarder();

        assertTrue(eTST.balanceForwarderEnabled(alice));
    }

    function test_Enable_AlreadyEnabledOk() public {
        vm.prank(alice);
        eTST.enableBalanceForwarder();
        vm.prank(alice);
        eTST.enableBalanceForwarder();

        assertTrue(eTST.balanceForwarderEnabled(alice));
    }

    function test_Enable_RevertsWhen_NoBalanceTracker() public {
        vm.skip(true);
        // todo: use eTST impl without balance tracker
        vm.expectRevert(Errors.E_BalanceForwarderUnsupported.selector);
        vm.prank(alice);
        eTST.enableBalanceForwarder();
    }

    function test_Disable() public {
        vm.prank(alice);
        eTST.enableBalanceForwarder();

        vm.expectEmit();
        emit Events.BalanceForwarderStatus(alice, false);
        vm.prank(alice);
        eTST.disableBalanceForwarder();

        assertFalse(eTST.balanceForwarderEnabled(alice));
        assertEq(MockBalanceTracker(balanceTracker).numCalls(), 2);
        assertEq(MockBalanceTracker(balanceTracker).calls(alice, 0, false), 2);
    }

    function test_Disable_EVCAuthenticate() public {
        vm.prank(alice);
        eTST.enableBalanceForwarder();

        vm.mockCall(address(evc), abi.encodeCall(evc.getCurrentOnBehalfOfAccount, (address(0))), abi.encode(alice, false));
        vm.prank(address(evc));
        eTST.disableBalanceForwarder();

        assertFalse(eTST.balanceForwarderEnabled(alice));
    }

    function test_Disable_AlreadyDisabledOk() public {
        assertFalse(eTST.balanceForwarderEnabled(alice));
        vm.prank(alice);
        eTST.disableBalanceForwarder();

        assertFalse(eTST.balanceForwarderEnabled(alice));
    }

    function test_Disable_RevertsWhen_NoBalanceTracker() public {
        vm.skip(true);
        // todo: use eTST impl without balance tracker
        vm.expectRevert(Errors.E_BalanceForwarderUnsupported.selector);
        vm.prank(alice);
        eTST.disableBalanceForwarder();
    }

    function _mintAndDeposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        assetTST.mint(user, amount);
        assetTST.approve(address(eTST), amount);
        eTST.deposit(amount, user);
        vm.stopPrank();
    }
}

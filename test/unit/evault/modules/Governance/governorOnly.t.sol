// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";

contract GovernanceTest_GovernorOnly is EVaultTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_GovernorAdmin(uint8 id) public {
        eTST.setFeeReceiver(address(0));
        eTST.setLTV(address(0), 0, 0, 0);
        eTST.clearLTV(address(0));
        eTST.setMaxLiquidationDiscount(0);
        eTST.setLiquidationCoolOffTime(0);
        eTST.setInterestRateModel(address(0));
        eTST.setHookConfig(address(0), 0);
        eTST.setConfigFlags(0);
        eTST.setCaps(0, 0);
        eTST.setInterestFee(0.1e4);
        eTST.setGovernorAdmin(address(0));

        // set the admin to the sub-account address
        address subAccount = getSubAccount(address(this), id);
        vm.prank(address(0));
        eTST.setGovernorAdmin(subAccount);

        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setFeeReceiver, address(0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setLTV, (address(0), 0, 0, 0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.clearLTV, address(0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setMaxLiquidationDiscount, 0));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setLiquidationCoolOffTime, 0));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setInterestRateModel, address(0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setHookConfig, (address(0), 0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setConfigFlags, 0));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setCaps, (0, 0)));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setInterestFee, 0.1e4));
        evc.call(address(eTST), subAccount, 0, abi.encodeCall(eTST.setGovernorAdmin, address(0)));
    }

    function testFuzz_UnauthorizedRevert_GovernorAdmin(uint8 id) public {
        vm.assume(id != 0);
        eTST.setGovernorAdmin(getSubAccount(address(this), id));

        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setFeeReceiver(address(0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setLTV(address(0), 0, 0, 0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.clearLTV(address(0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setMaxLiquidationDiscount(0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setLiquidationCoolOffTime(0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setInterestRateModel(address(0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setHookConfig(address(0), 0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setConfigFlags(0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setCaps(0, 0);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setInterestFee(0.1e4);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setGovernorAdmin(address(0));

        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setFeeReceiver, address(0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setLTV, (address(0), 0, 0, 0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.clearLTV, address(0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setMaxLiquidationDiscount, 0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setLiquidationCoolOffTime, 0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setInterestRateModel, address(0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setHookConfig, (address(0), 0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setConfigFlags, 0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setCaps, (0, 0)));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setInterestFee, 0.1e4));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        evc.call(address(eTST), address(this), 0, abi.encodeCall(eTST.setGovernorAdmin, address(0)));
    }
}

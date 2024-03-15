// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {GovernanceModule} from "src/EVault/modules/Governance.sol";
import "src/EVault/modules/Governance.sol";
import "src/EVault/shared/Constants.sol";
import "src/EVault/shared/types/Types.sol";

uint256 constant DEFAULT_INTEREST_FEE = 0.23e4; // TODO expose in harness from Initialize module

contract ERC4626Test_ProtocolConfig is EVaultTestBase {
    using TypesLib for uint256;

    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();

        assetTST.mint(user, type(uint256).max);
        vm.prank(user);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    function test_interestFees_normal() public {
        assertEq(eTST.interestFee(), DEFAULT_INTEREST_FEE);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.005e4);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.9e4);

        eTST.setInterestFee(0.4e4);
        assertEq(eTST.interestFee(), 0.4e4);
    }

    function test_interestFees_extended() public {
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), true, 0.002e4, 0.6e4);

        eTST.setInterestFee(0.005e4);
        assertEq(eTST.interestFee(), 0.005e4);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.001e4);

        eTST.setInterestFee(0.55e4);
        assertEq(eTST.interestFee(), 0.55e4);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.65e4);
    }

    function test_interestFees_maliciousProtocolConfig() public {
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), true, 0.8e4, 0.9e4);

        // Vault won't call into protocolConfig with reasonable interestFee

        eTST.setInterestFee(0.35e4);
        assertEq(eTST.interestFee(), 0.35e4);

        // But will outside the always-valid range

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.55e4);
    }

    function test_override_interestFeeRanges() public {
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), true, 1e3, type(uint16).max);

        (uint16 vaultMinInterestFee, uint16 vaultMaxInterestFee) = protocolConfig.interestFeeRanges(address(eTST));

        assertEq(vaultMinInterestFee, 1e3);
        assertEq(vaultMaxInterestFee, type(uint16).max);

        // reset vault to use generic ranges
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), false, 1e3, type(uint16).max);

        (uint16 genericMinInterestFee, uint16 genericMaxInterestFee) = protocolConfig.interestFeeRanges(address(0));
        (vaultMinInterestFee, vaultMaxInterestFee) = protocolConfig.interestFeeRanges(address(eTST));

        assertEq(vaultMinInterestFee, genericMinInterestFee);
        assertEq(vaultMaxInterestFee, genericMaxInterestFee);
    }

    function test_updateProtocolConfig() public {
        address newFeeReceiver = makeAddr("newFeeReceiver");

        vm.prank(admin);
        protocolConfig.setFeeReceiver(newFeeReceiver);

        (address protocolFeeReceiver,) = protocolConfig.protocolFeeConfig(address(0));
        assertEq(protocolFeeReceiver, newFeeReceiver);


        vm.prank(admin);
        protocolConfig.setProtocolFeeShare(2e17);

        (, uint256 feeShare) = protocolConfig.protocolFeeConfig(address(0));
        assertEq(feeShare, 2e17);
    }

    function test_override_feeConfig() public {
        address newFeeReceiver = makeAddr("newFeeReceiver");
        uint256 newFeeShare = 2e17;

        vm.prank(admin);
        protocolConfig.setFeeConfigSetting(address(eTST), true, newFeeReceiver, newFeeShare);

        (address feeReceiver, uint256 feeShare) = protocolConfig.protocolFeeConfig(address(eTST));

        assertEq(feeReceiver, newFeeReceiver);
        assertEq(feeShare, newFeeShare);

        // reset vault to use generic ranges
        vm.prank(admin);
        protocolConfig.setFeeConfigSetting(address(eTST), false, newFeeReceiver, newFeeShare);

        (address genericFeeReceiver, uint256 genericFeeShare) = protocolConfig.protocolFeeConfig(address(0));
        (feeReceiver, feeShare) = protocolConfig.protocolFeeConfig(address(eTST));

        assertEq(genericFeeReceiver, feeReceiver);
        assertEq(genericFeeShare, feeShare);
    }
}

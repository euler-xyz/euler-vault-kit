// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {GovernanceModule} from "src/EVault/modules/Governance.sol";
import "src/EVault/modules/Governance.sol";
import "src/EVault/shared/Constants.sol";
import "src/EVault/shared/types/Types.sol";

uint256 constant DEFAULT_INTEREST_FEE = CONFIG_SCALE * 23 / 100; // TODO expose in harness from Initialize module

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
        eTST.setInterestFee(0.005 * 10_000);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.9 * 10_000);

        eTST.setInterestFee(0.4 * 10_000);
        assertEq(eTST.interestFee(), 0.4 * 10_000);
    }

    function test_interestFees_extended() public {
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), true, 0.002 * 10_000, 0.6 * 10_000);

        eTST.setInterestFee(0.005 * 10_000);
        assertEq(eTST.interestFee(), 0.005 * 10_000);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.001 * 10_000);

        eTST.setInterestFee(0.55 * 10_000);
        assertEq(eTST.interestFee(), 0.55 * 10_000);

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.65 * 10_000);
    }

    function test_interestFees_maliciousProtocolConfig() public {
        vm.prank(admin);
        protocolConfig.setInterestFeeRange(address(eTST), true, 0.8 * 10_000, 0.9 * 10_000);

        // Vault won't call into protocolConfig with reasonable interestFee

        eTST.setInterestFee(0.35 * 10_000);
        assertEq(eTST.interestFee(), 0.35 * 10_000);

        // But will outside the always-valid range

        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(0.55 * 10_000);
    }
}

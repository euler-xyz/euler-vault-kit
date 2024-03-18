// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ESVaultTestBase, ESynth, ESVault} from "./ESVaultTestBase.t.sol";
import {Errors} from "../../../src/EVault/shared/Errors.sol";

contract ESVaultTestInterestFee is ESVaultTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_interest_fee() public {
        uint256 interestFee = eTST.interestFee();
        assertEq(interestFee, 1e4);
    }

    function test_set_interest_fee() public {
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.setInterestFee(uint16(1));
        
    }
}

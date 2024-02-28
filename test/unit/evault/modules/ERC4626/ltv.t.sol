// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract ERC4626Test_LTVRamp is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;

    function setUp() public override {
        super.setUp();

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);
    }


    function test_rampDown() public {
        eTST.setLTV(address(eTST2), cfgScale(0.9e3), 0);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.9e3));

        eTST.setLTV(address(eTST2), cfgScale(0.4e3), 1000);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.4e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.9e3));

        skip(200);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.4e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.8e3));

        skip(300);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.4e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.65e3));

        skip(500);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.4e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.4e3));
    }

    function test_rampUp() public {
        eTST.setLTV(address(eTST2), cfgScale(0.8e3), 1000);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.0e3));

        skip(250);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.2e3));

        skip(500);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.6e3));

        skip(5000);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.8e3));
    }


    function test_rampRetarget() public {
        eTST.setLTV(address(eTST2), cfgScale(0.8e3), 1000);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.0e3));

        skip(250);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.8e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.2e3));

        eTST.setLTV(address(eTST2), cfgScale(0.1e3), 1000);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.1e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.2e3));

        skip(500);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.1e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.15e3));

        skip(600);

        assertEq(eTST.LTV(address(eTST2)), cfgScale(0.1e3));
        assertEq(eTST.LTVRamped(address(eTST2)), cfgScale(0.1e3));
    }


    // From 1000 base to CONFIG_SCALE

    function cfgScale(uint n) private pure returns (uint16) {
        return uint16(n * CONFIG_SCALE / 1000);
    }
}

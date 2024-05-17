// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";

contract Governance_views is EVaultTestBase {
    function test_protocolFeeShare() public {
        assertEq(eTST.protocolFeeShare(), 0.1e4);

        startHoax(admin);
        protocolConfig.setProtocolFeeShare(0.4e4);

        assertEq(eTST.protocolFeeShare(), 0.4e4);
    }

    function test_protocolFeeReceiver() public {
        assertEq(eTST.protocolFeeReceiver(), protocolFeeReceiver);

        startHoax(admin);
        protocolConfig.setFeeReceiver(address(123));

        assertEq(eTST.protocolFeeReceiver(), address(123));
    }

    function test_LTVFull() public {
        address eTST3 = makeAddr("eTST3");

        (uint48 targetTimestamp1, uint16 targetLTV1, uint32 rampDuration1, uint16 originalLTV1) =
            eTST.LTVFull(address(eTST2));
        (uint48 targetTimestamp2, uint16 targetLTV2, uint32 rampDuration2, uint16 originalLTV2) = eTST.LTVFull(eTST3);

        assertEq(targetTimestamp1, 0);
        assertEq(targetLTV1, 0);
        assertEq(rampDuration1, 0);
        assertEq(originalLTV1, 0);

        assertEq(targetTimestamp2, 0);
        assertEq(targetLTV2, 0);
        assertEq(rampDuration2, 0);
        assertEq(originalLTV2, 0);

        eTST.setLTV(address(eTST2), 0.3e4, 0);
        eTST.setLTV(eTST3, 0.56e4, 0);

        (targetTimestamp1, targetLTV1, rampDuration1, originalLTV1) = eTST.LTVFull(address(eTST2));
        (targetTimestamp2, targetLTV2, rampDuration2, originalLTV2) = eTST.LTVFull(eTST3);

        assertEq(targetTimestamp1, 1);
        assertEq(targetLTV1, 0.3e4);
        assertEq(rampDuration1, 0);
        assertEq(originalLTV1, 0);

        assertEq(targetTimestamp2, 1);
        assertEq(targetLTV2, 0.56e4);
        assertEq(rampDuration2, 0);
        assertEq(originalLTV2, 0);

        skip(5000);

        eTST.setLTV(address(eTST2), 0.15e4, 100);
        eTST.setLTV(eTST3, 0.36e4, 1000);

        (targetTimestamp1, targetLTV1, rampDuration1, originalLTV1) = eTST.LTVFull(address(eTST2));
        (targetTimestamp2, targetLTV2, rampDuration2, originalLTV2) = eTST.LTVFull(eTST3);

        assertEq(targetTimestamp1, 5001 + 100);
        assertEq(targetLTV1, 0.15e4);
        assertEq(rampDuration1, 100);
        assertEq(originalLTV1, 0.3e4);

        assertEq(targetTimestamp2, 5001 + 1000);
        assertEq(targetLTV2, 0.36e4);
        assertEq(rampDuration2, 1000);
        assertEq(originalLTV2, 0.56e4);
    }

    function test_protocolConfigAddress() public view {
        assertEq(eTST.protocolConfigAddress(), address(protocolConfig));
    }

    function test_permit2Address() public view {
        assertEq(eTST.permit2Address(), permit2);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../../../src/Synths/IRMSynth.sol";
import "../../mocks/MockPriceOracle.sol";

contract IRMSynthTest is Test {
    IRMSynth public irm;
    MockPriceOracle public oracle;

    address public SYNTH = makeAddr("synth");
    address public REFERENCE_ASSET = makeAddr("referenceAsset");

    function setUp() public {
        oracle = new MockPriceOracle();
        irm = new IRMSynth(SYNTH, REFERENCE_ASSET, address(oracle));

        oracle.setPrice(SYNTH, REFERENCE_ASSET, 1e18);
    }

    function test_IRMSynth_InitialRate() public {
        assertEq(irm.computeInterestRate(address(0), 0, 0), uint216(irm.BASE_RATE()));
    }

    function test_IRMSynth_AjustInterval() public {
        uint256 adjustInterval = irm.ADJUST_INTERVAL();
        skip(adjustInterval);
        irm.computeInterestRate(address(0), 0, 0);
        uint256 lastUpdatedBefore = irm.getIRMData().lastUpdated;
        assertEq(lastUpdatedBefore, block.timestamp);
        skip(adjustInterval / 2);
        irm.computeInterestRate(address(0), 0, 0);
        uint256 lastUpdatedAfter = irm.getIRMData().lastUpdated;
        assertEq(lastUpdatedAfter, lastUpdatedBefore);
    }

    function test_IRMSynth_0Quote() public {
        oracle.setPrice(SYNTH, REFERENCE_ASSET, 0);
        IRMSynth.IRMData memory irmDataBefore = irm.getIRMData();
        skip(irm.ADJUST_INTERVAL());
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmDataAfter = irm.getIRMData();

        // Should not have updated the rate or last updated
        assertEq(irmDataBefore.lastRate, irmDataAfter.lastRate);
        assertEq(irmDataBefore.lastUpdated, irmDataAfter.lastUpdated);
    }

    function testIRMSynth_RateAdjustUp() public {
        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() / 2);

        IRMSynth.IRMData memory irmDataBefore = irm.getIRMData();
        skip(irm.ADJUST_INTERVAL());
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmDataAfter = irm.getIRMData();

        // Should have updated the rate and last updated
        assertEq(irmDataAfter.lastUpdated, block.timestamp);
        assertEq(irmDataAfter.lastRate, irmDataBefore.lastRate * irm.ADJUST_FACTOR() / irm.ADJUST_ONE());
    }

    function test_IRMSynth_RateAdjustDown() public {
        // adjust the rate up first two times
        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() / 2);
        skip(irm.ADJUST_INTERVAL());
        irm.computeInterestRate(address(0), 0, 0);
        skip(irm.ADJUST_INTERVAL());
        irm.computeInterestRate(address(0), 0, 0);

        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() * 2);
        IRMSynth.IRMData memory irmDataBefore = irm.getIRMData();
        skip(irm.ADJUST_INTERVAL());
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmDataAfter = irm.getIRMData();

        // Should have updated the rate and last updated
        assertEq(irmDataAfter.lastUpdated, block.timestamp);
        assertEq(irmDataAfter.lastRate, irmDataBefore.lastRate * irm.ADJUST_ONE() / irm.ADJUST_FACTOR());
    }

    function test_IRMSynth_RateMinimum() public {
        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() * 2);

        // Rate already at minimum, try to adjust regardless
        skip(irm.ADJUST_INTERVAL());
        IRMSynth.IRMData memory irmDataBefore = irm.getIRMData();
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmDataAfter = irm.getIRMData();

        // Rate should not have changed but last updated should have
        assertEq(irmDataAfter.lastUpdated, block.timestamp);
        assertEq(irmDataAfter.lastRate, irmDataBefore.lastRate);
    }

    function test_IRMSynth_RateMax() public {
        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() / 2);

        // Loop till at max rate
        uint256 maxRate = irm.MAX_RATE();
        while (irm.getIRMData().lastRate < maxRate) {
            skip(irm.ADJUST_INTERVAL());
            irm.computeInterestRate(address(0), 0, 0);
        }

        skip(irm.ADJUST_INTERVAL());
        IRMSynth.IRMData memory irmDataBefore = irm.getIRMData();
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmDataAfter = irm.getIRMData();

        // Rate should not have changed but last updated should have
        assertEq(irmDataAfter.lastUpdated, block.timestamp);
        assertEq(irmDataAfter.lastRate, irmDataBefore.lastRate);
    }

    function test_computeInterestRateView() public {
        oracle.setPrice(SYNTH, REFERENCE_ASSET, irm.TARGET_QUOTE() / 2);

        uint256 rate = irm.computeInterestRateView(address(0), 0, 0);
        irm.computeInterestRate(address(0), 0, 0);
        IRMSynth.IRMData memory irmData = irm.getIRMData();

        assertEq(rate, irmData.lastRate);

        skip(irm.ADJUST_INTERVAL());
        rate = irm.computeInterestRateView(address(0), 0, 0);
        irmData = irm.getIRMData();

        assertNotEq(rate, irmData.lastRate);

        irm.computeInterestRate(address(0), 0, 0);
        irmData = irm.getIRMData();

        assertEq(rate, irmData.lastRate);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "../../../src/InterestRateModels/IIRM.sol";
import {IRMAdaptiveCurve} from "../../../src/InterestRateModels/IRMAdaptiveCurve.sol";
import {MathTesting} from "../../helpers/MathTesting.sol";

contract IRMAdaptiveCurveTest is Test, MathTesting {
    address constant VAULT = address(0x1234);

    /// @dev 4:1
    int256 constant CURVE_STEEPNESS = 4 ether;
    /// @dev 50%
    int256 constant ADJUSTMENT_SPEED = 50 ether / int256(365 days);
    /// @dev 90%
    int256 constant TARGET_UTILIZATION = 0.9 ether;
    /// @dev 4%
    int256 constant INITIAL_RATE_AT_TARGET = 0.04 ether / int256(365 days);
    /// @dev 0.1%
    int256 constant MIN_RATE_AT_TARGET = 0.001 ether / int256(365 days);
    /// @dev 200%
    int256 constant MAX_RATE_AT_TARGET = 2.0 ether / int256(365 days);

    IRMAdaptiveCurve irm;

    function setUp() public {
        irm = new IRMAdaptiveCurve(
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED,
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET
        );
        vm.startPrank(VAULT);
    }

    function test_OnlyVaultCanMutateIRMState() public {
        irm.computeInterestRate(VAULT, 5, 6);

        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        vm.startPrank(address(0x2345));
        irm.computeInterestRate(VAULT, 5, 6);
    }

    function computeRateAtUtilization(uint256 utilizationRate) internal returns (uint256) {
        if (utilizationRate == 0) return irm.computeInterestRate(VAULT, 0, 0);
        if (utilizationRate == 1e18) return irm.computeInterestRate(VAULT, 0, 1e18);

        uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
        return irm.computeInterestRate(VAULT, 1e18, borrows);
    }

    function test_IRMCalculations() public {
        // First call returns `INITIAL_RATE_AT_TARGET.
        uint256 rate1 = computeRateAtUtilization(0.9e18);
        assertEq(rate1, uint256(INITIAL_RATE_AT_TARGET));

        // Utilization remains at `TARGET_UTILIZATION` so the rate remains at `INITIAL_RATE_AT_TARGET`.
        skip(1 minutes);
        uint256 rate2 = computeRateAtUtilization(0.9e18);
        assertEq(rate2, uint256(INITIAL_RATE_AT_TARGET));
        skip(365 days);
        uint256 rate3 = computeRateAtUtilization(0.9e18);
        assertEq(rate3, uint256(INITIAL_RATE_AT_TARGET));

        // Utilization climbs to 100% without time delay. The rate is 4x larger than initial.
        uint256 rate4 = computeRateAtUtilization(1e18);
        assertEq(rate4, uint256(CURVE_STEEPNESS * INITIAL_RATE_AT_TARGET / 1e18));

        // Utilization goes down to 0% without time delay. The rate is 4x smaller than initial.
        uint256 rate5 = computeRateAtUtilization(0);
        assertEq(rate5, uint256(1e18 * INITIAL_RATE_AT_TARGET / CURVE_STEEPNESS));

        // Utilization goes back to 90% without time delay. The rate is back at initial.
        uint256 rate6 = computeRateAtUtilization(0.9e18);
        assertEq(rate6, uint256(INITIAL_RATE_AT_TARGET));

        // Utilization climbs to 100% after 1 day.
        // The rate is 4x larger than initial + the whole curve has adjusted up.
        skip(1 days);
        uint256 rate7 = computeRateAtUtilization(1e18);
        assertGt(rate7, uint256(CURVE_STEEPNESS * INITIAL_RATE_AT_TARGET / 1e18));
        uint256 rate8 = computeRateAtUtilization(1e18);
        // Utilization goes back to 90% without time delay. The rate is back at initial + adjustment factor.
        uint256 rate9 = computeRateAtUtilization(0.9e18);
        assertEq(rate8, uint256(CURVE_STEEPNESS) * rate9 / 1e18);
    }
}

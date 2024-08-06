// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IIRM.sol";
import "../EVault/shared/lib/ExpWad.sol";
import {IEVault} from "../EVault/IEVault.sol";

/// @title IRMAdaptiveCurve
/// @author Morpho Labs
/// (https://github.com/morpho-org/morpho-blue-irm/blob/main/src/adaptive-curve-irm/AdaptiveCurveIrm.sol)
/// @author Modified by Euler Labs (https://www.eulerlabs.com/).
/// @custom:contact security@morpho.org
contract IRMAdaptiveCurve is IIRM {
    struct IRState {
        int224 rateAtTarget;
        uint32 lastUpdate;
    }

    mapping(address => IRState) public irState;

    int256 internal constant WAD = 1e18;
    int256 public immutable CURVE_STEEPNESS;
    int256 public immutable ADJUSTMENT_SPEED;
    int256 public immutable TARGET_UTILIZATION;
    int256 public immutable INITIAL_RATE_AT_TARGET;
    int256 public immutable MIN_RATE_AT_TARGET;
    int256 public immutable MAX_RATE_AT_TARGET;

    constructor(
        int256 _CURVE_STEEPNESS,
        int256 _ADJUSTMENT_SPEED,
        int256 _TARGET_UTILIZATION,
        int256 _INITIAL_RATE_AT_TARGET,
        int256 _MIN_RATE_AT_TARGET,
        int256 _MAX_RATE_AT_TARGET
    ) {
        CURVE_STEEPNESS = _CURVE_STEEPNESS;
        ADJUSTMENT_SPEED = _ADJUSTMENT_SPEED;
        TARGET_UTILIZATION = _TARGET_UTILIZATION;
        INITIAL_RATE_AT_TARGET = _INITIAL_RATE_AT_TARGET;
        MIN_RATE_AT_TARGET = _MIN_RATE_AT_TARGET;
        MAX_RATE_AT_TARGET = _MAX_RATE_AT_TARGET;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        (uint256 avgRate, int256 endRateAtTarget) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(int224(endRateAtTarget), uint32(block.timestamp));
        return avgRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 avgRate,) = computeInterestRateInternal(vault, cash, borrows);
        return avgRate;
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for
    /// @param cash Amount of assets held directly by the vault
    /// @param borrows Amount of assets lent out to borrowers by the vault
    /// @dev Assumes that
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, int256)
    {
        // Initialize rate if this is the first call.
        IRState memory state = irState[vault];
        if (state.lastUpdate == 0) return (uint256(INITIAL_RATE_AT_TARGET), INITIAL_RATE_AT_TARGET);

        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        int256 utilization = totalAssets == 0 ? int256(0) : int256(borrows * 1e18 / totalAssets);

        // Calculate the deviation of the current utilization wrt. the target utilization.
        int256 errNormFactor = utilization > TARGET_UTILIZATION ? WAD - TARGET_UTILIZATION : TARGET_UTILIZATION;
        int256 err = (utilization - TARGET_UTILIZATION) * 1e18 / errNormFactor;

        int256 startRateAtTarget = state.rateAtTarget;

        int256 avgRateAtTarget;
        int256 endRateAtTarget;

        if (startRateAtTarget == 0) {
            // First interaction.
            avgRateAtTarget = INITIAL_RATE_AT_TARGET;
            endRateAtTarget = INITIAL_RATE_AT_TARGET;
        } else {
            // The speed is assumed constant between two updates, but it is in fact not constant because of interest.
            // So the rate is always underestimated.
            int256 speed = ADJUSTMENT_SPEED * err / WAD;
            // market.lastUpdate != 0 because it is not the first interaction with this market.
            // Safe "unchecked" cast because block.timestamp - market.lastUpdate <= block.timestamp <= type(int256).max.
            int256 elapsed = int256(block.timestamp - state.lastUpdate);
            int256 linearAdaptation = speed * elapsed;

            if (linearAdaptation == 0) {
                // If linearAdaptation == 0, avgRateAtTarget = endRateAtTarget = startRateAtTarget;
                avgRateAtTarget = startRateAtTarget;
                endRateAtTarget = startRateAtTarget;
            } else {
                // Formula of the average rate that should be returned to Morpho Blue:
                // avg = 1/T * ∫_0^T curve(startRateAtTarget*exp(speed*x), err) dx
                // The integral is approximated with the trapezoidal rule:
                // avg ~= 1/T * Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / 2 * T/N
                // Where f(x) = startRateAtTarget*exp(speed*x)
                // avg ~= Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / (2 * N)
                // As curve is linear in its first argument:
                // avg ~= curve([Σ_i=1^N [f((i-1) * T/N) + f(i * T/N)] / (2 * N), err)
                // avg ~= curve([(f(0) + f(T))/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
                // avg ~= curve([(startRateAtTarget + endRateAtTarget)/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
                // With N = 2:
                // avg ~= curve([(startRateAtTarget + endRateAtTarget)/2 + startRateAtTarget*exp(speed*T/2)] / 2, err)
                // avg ~= curve([startRateAtTarget + endRateAtTarget + 2*startRateAtTarget*exp(speed*T/2)] / 4, err)
                endRateAtTarget = _newRateAtTarget(startRateAtTarget, linearAdaptation);
                int256 midRateAtTarget = _newRateAtTarget(startRateAtTarget, linearAdaptation / 2);
                avgRateAtTarget = (startRateAtTarget + endRateAtTarget + 2 * midRateAtTarget) / 4;
            }
        }

        // Safe "unchecked" cast because avgRateAtTarget >= 0.
        return (uint256(_curve(avgRateAtTarget, err)), endRateAtTarget);
    }

    /// @dev Returns the rate for a given `_rateAtTarget` and an `err`.
    /// The formula of the curve is the following:
    /// r = ((1-1/C)*err + 1) * rateAtTarget if err < 0
    ///     ((C-1)*err + 1) * rateAtTarget else.
    function _curve(int256 _rateAtTarget, int256 err) internal view returns (int256) {
        // Non negative because 1 - 1/C >= 0, C - 1 >= 0.
        int256 coeff;
        if (err < 0) {
            coeff = WAD - WAD * WAD / CURVE_STEEPNESS;
        } else {
            coeff = CURVE_STEEPNESS - WAD;
        }
        // Non negative if _rateAtTarget >= 0 because if err < 0, coeff <= 1.
        return ((coeff * err / WAD) + WAD) * int256(_rateAtTarget) / WAD;
    }

    /// @dev Returns the new rate at target, for a given `startRateAtTarget` and a given `linearAdaptation`.
    /// The formula is: max(min(startRateAtTarget * exp(linearAdaptation), MAX_RATE_AT_TARGET), MIN_RATE_AT_TARGET).
    function _newRateAtTarget(int256 startRateAtTarget, int256 linearAdaptation) internal view returns (int256) {
        // Non negative because MIN_RATE_AT_TARGET > 0.
        int256 rate = startRateAtTarget * ExpWad.expWad(linearAdaptation) / WAD;
        if (rate < MIN_RATE_AT_TARGET) return MIN_RATE_AT_TARGET;
        if (rate > MAX_RATE_AT_TARGET) return MAX_RATE_AT_TARGET;
        return rate;
    }
}

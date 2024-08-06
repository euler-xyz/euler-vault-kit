// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IIRM.sol";
import "../EVault/shared/lib/ExpWad.sol";
import {IEVault} from "../EVault/IEVault.sol";

/// @title IRMAdaptiveCurve
/// @author Morpho Labs
/// (https://github.com/morpho-org/morpho-blue-irm/blob/main/src/adaptive-curve-irm/AdaptiveCurveIrm.sol)
/// @author Modified by Euler Labs (https://www.eulerlabs.com/).
/// @custom:contact security@euler.xyz
contract IRMAdaptiveCurve is IIRM {
    /// @dev Unit for internal precision.
    int256 internal constant WAD = 1e18;
    /// @notice The utilization rate targeted by the interest rate model.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    int256 public immutable kink;
    /// @notice The initial interest rate at the kink level.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable initialKinkRate;
    /// @notice The minimum interest rate at the kink level that the model can adjust to.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable minKinkRate;
    /// @notice The maximum interest rate at the kink level that the model can adjust to.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable maxKinkRate;
    /// @notice The steepness of interest rate function below and above the kink.
    /// @dev In WAD units e.g. 4e18 = 400%.
    int256 public immutable slope;
    /// @notice The speed at which the kink rate is adjusted up or down.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable adjustmentSpeed;

    struct IRState {
        int224 kinkRate;
        uint32 lastUpdate;
    }

    mapping(address => IRState) public irState;

    /// @notice Deploy IRMAdaptiveCurve
    /// @param _kink The utilization rate targeted by the interest rate model.
    /// @param _initialKinkRate The initial interest rate at the kink level.
    /// @param _minKinkRate The minimum interest rate at the kink level that the model can adjust to.
    /// @param _maxKinkRate The maximum interest rate at the kink level that the model can adjust to.
    /// @param _slope The steepness of interest rate function below and above the kink.
    /// @param _adjustmentSpeed The speed at which the kink rate is adjusted up or down.
    constructor(
        int256 _kink,
        int256 _initialKinkRate,
        int256 _minKinkRate,
        int256 _maxKinkRate,
        int256 _slope,
        int256 _adjustmentSpeed
    ) {
        kink = _kink;
        initialKinkRate = _initialKinkRate;
        minKinkRate = _minKinkRate;
        maxKinkRate = _maxKinkRate;
        slope = _slope;
        adjustmentSpeed = _adjustmentSpeed;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        (uint256 avgRate, int256 endKinkRate) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(int224(endKinkRate), uint32(block.timestamp));
        return avgRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 avgRate,) = computeInterestRateInternal(vault, cash, borrows);
        return avgRate;
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, int256)
    {
        // Initialize rate if this is the first call.
        IRState memory state = irState[vault];
        if (state.lastUpdate == 0) return (uint256(initialKinkRate), initialKinkRate);

        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        int256 utilization = totalAssets == 0 ? int256(0) : int256(borrows * 1e18 / totalAssets);

        // Calculate the deviation of the current utilization wrt. the target utilization.
        int256 errNormFactor = utilization > kink ? WAD - kink : kink;
        int256 err = (utilization - kink) * 1e18 / errNormFactor;

        int256 startKinkRate = state.kinkRate;

        int256 avgKinkRate;
        int256 endKinkRate;

        if (startKinkRate == 0) {
            // First interaction.
            avgKinkRate = initialKinkRate;
            endKinkRate = initialKinkRate;
        } else {
            // The speed is assumed constant between two updates, but it is in fact not constant because of interest.
            // So the rate is always underestimated.
            int256 speed = adjustmentSpeed * err / WAD;
            // market.lastUpdate != 0 because it is not the first interaction with this market.
            // Safe "unchecked" cast because block.timestamp - market.lastUpdate <= block.timestamp <= type(int256).max.
            int256 elapsed = int256(block.timestamp - state.lastUpdate);
            int256 linearAdaptation = speed * elapsed;

            if (linearAdaptation == 0) {
                // If linearAdaptation == 0, avgKinkRate = endKinkRate = startKinkRate;
                avgKinkRate = startKinkRate;
                endKinkRate = startKinkRate;
            } else {
                // Formula of the average rate that should be returned:
                // avg = 1/T * ∫_0^T curve(startKinkRate*exp(speed*x), err) dx
                // The integral is approximated with the trapezoidal rule:
                // avg ~= 1/T * Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / 2 * T/N
                // Where f(x) = startKinkRate*exp(speed*x)
                // avg ~= Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / (2 * N)
                // As curve is linear in its first argument:
                // avg ~= curve([Σ_i=1^N [f((i-1) * T/N) + f(i * T/N)] / (2 * N), err)
                // avg ~= curve([(f(0) + f(T))/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
                // avg ~= curve([(startKinkRate + endKinkRate)/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
                // With N = 2:
                // avg ~= curve([(startKinkRate + endKinkRate)/2 + startKinkRate*exp(speed*T/2)] / 2, err)
                // avg ~= curve([startKinkRate + endKinkRate + 2*startKinkRate*exp(speed*T/2)] / 4, err)
                endKinkRate = _newKinkRate(startKinkRate, linearAdaptation);
                int256 midKinkRate = _newKinkRate(startKinkRate, linearAdaptation / 2);
                avgKinkRate = (startKinkRate + endKinkRate + 2 * midKinkRate) / 4;
            }
        }

        // Safe "unchecked" cast because avgKinkRate >= 0.
        return (uint256(_curve(avgKinkRate, err)), endKinkRate);
    }

    /// @dev Returns the rate for a given `_kinkRate` and an `err`.
    /// The formula of the curve is the following:
    /// r = ((1-1/C)*err + 1) * kinkRate if err < 0
    ///     ((C-1)*err + 1) * kinkRate else.
    function _curve(int256 _kinkRate, int256 err) internal view returns (int256) {
        // Non negative because 1 - 1/C >= 0, C - 1 >= 0.
        int256 coeff;
        if (err < 0) {
            coeff = WAD - WAD * WAD / slope;
        } else {
            coeff = slope - WAD;
        }
        // Non negative if _kinkRate >= 0 because if err < 0, coeff <= 1.
        return ((coeff * err / WAD) + WAD) * int256(_kinkRate) / WAD;
    }

    /// @dev Returns the new rate at target, for a given `startKinkRate` and a given `linearAdaptation`.
    /// The formula is: max(min(startKinkRate * exp(linearAdaptation), maxKinkRate), minKinkRate).
    function _newKinkRate(int256 startKinkRate, int256 linearAdaptation) internal view returns (int256) {
        // Non negative because minKinkRate > 0.
        int256 rate = startKinkRate * ExpWad.expWad(linearAdaptation) / WAD;
        if (rate < minKinkRate) return minKinkRate;
        if (rate > maxKinkRate) return maxKinkRate;
        return rate;
    }
}

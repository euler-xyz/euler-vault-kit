// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "../EVault/IEVault.sol";
import {RPow} from "../EVault/shared/lib/RPow.sol";

abstract contract LensUtils {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400;
    uint256 internal constant ONE = 1e27;
    uint256 internal constant CONFIG_SCALE = 1e4;
    uint256 internal constant TTL_HS_ACCURACY = ONE / 1e4;
    int256 internal constant TTL_COMPUTATION_MIN = 0;
    int256 internal constant TTL_COMPUTATION_MAX = 400 * 1 days;
    int256 public constant TTL_INFINITY = type(int256).max;
    int256 public constant TTL_MORE_THAN_ONE_YEAR = type(int256).max - 1;
    int256 public constant TTL_LIQUIDATION = -1;
    int256 public constant TTL_ERROR = -2;

    /// @dev for tokens like MKR which return bytes32 on name() or symbol()
    function getStringOrBytes32(address contractAddress, bytes4 selector) internal view returns (string memory) {
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(selector));

        return success ? result.length == 32 ? string(abi.encodePacked(result)) : abi.decode(result, (string)) : "";
    }

    function getDecimals(address contractAddress) internal view returns (uint8) {
        (bool success, bytes memory data) =
            contractAddress.staticcall(abi.encodeCall(IEVault(contractAddress).decimals, ()));

        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function computeInterestRates(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        internal
        pure
        returns (uint256 supplySPY, uint256 borrowAPY, uint256 supplyAPY)
    {
        uint256 totalAssets = cash + borrows;
        bool overflowBorrow;
        bool overflowSupply;

        supplySPY =
            totalAssets == 0 ? 0 : borrowSPY * borrows * (CONFIG_SCALE - interestFee) / totalAssets / CONFIG_SCALE;
        (borrowAPY, overflowBorrow) = RPow.rpow(borrowSPY + ONE, SECONDS_PER_YEAR, ONE);
        (supplyAPY, overflowSupply) = RPow.rpow(supplySPY + ONE, SECONDS_PER_YEAR, ONE);

        if (overflowBorrow || overflowSupply) return (supplySPY, 0, 0);

        borrowAPY -= ONE;
        supplyAPY -= ONE;
    }

    function calculateTimeToLiquidation(
        address liabilityVault,
        uint256 liabilityValue,
        address[] memory collaterals,
        uint256[] memory collateralValues
    ) internal view returns (int256) {
        // get borrow interest rate
        uint256 liabilitySPY;
        try IEVault(liabilityVault).interestRate() returns (uint256 _spy) {
            liabilitySPY = _spy;
        } catch {}

        // if there's no borrow interest rate, time to liquidation is infinite
        if (liabilitySPY == 0) return TTL_INFINITY;

        // get individual collateral interest rates
        uint256[] memory collateralSPYs = new uint256[](collaterals.length);
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];
            uint256 borrowSPY;
            try IEVault(collateral).interestRate() returns (uint256 _spy) {
                borrowSPY = _spy;
            } catch {}

            if (borrowSPY > 0) {
                (collateralSPYs[i],,) = computeInterestRates(
                    borrowSPY,
                    IEVault(collateral).cash(),
                    IEVault(collateral).totalBorrows(),
                    IEVault(collateral).interestFee()
                );
            }
        }

        int256 minTTL = TTL_COMPUTATION_MIN;
        int256 maxTTL = TTL_COMPUTATION_MAX;
        int256 ttl;

        // calculate time to liquidation using binary search
        while (true) {
            ttl = minTTL + (maxTTL - minTTL) / 2;

            // break if the search range is too small
            if (maxTTL <= minTTL + 1 days) break;
            if (ttl < 1 days) break;

            // calculate the liability interest accrued
            uint256 liabilityInterest;
            {
                (uint256 multiplier, bool overflow) = RPow.rpow(liabilitySPY + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                liabilityInterest = liabilityValue * multiplier / ONE - liabilityValue;
            }

            // calculate the collaterals interest accrued
            uint256 collateralValue;
            uint256 collateralInterest;
            for (uint256 i = 0; i < collaterals.length; ++i) {
                (uint256 multiplier, bool overflow) = RPow.rpow(collateralSPYs[i] + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                collateralValue += collateralValues[i];
                collateralInterest = collateralValues[i] * multiplier / ONE - collateralValues[i];
            }

            // calculate the health factor
            uint256 hs = (collateralValue + collateralInterest) * ONE / (liabilityValue + liabilityInterest);

            // if the collateral interest accrues fater than the liability interest, the account should never be
            // liquidated
            if (collateralInterest >= liabilityInterest) return TTL_INFINITY;

            // if the health factor is within the acceptable range, return the time to liquidation
            if (hs >= ONE && hs - ONE <= TTL_HS_ACCURACY) break;
            if (hs < ONE && ONE - hs <= TTL_HS_ACCURACY) break;

            // adjust the search range
            if (hs >= ONE) minTTL = ttl + 1 days;
            else maxTTL = ttl - 1 days;
        }

        return ttl > int256(SECONDS_PER_YEAR) ? TTL_MORE_THAN_ONE_YEAR : int256(ttl) / 1 days;
    }
}

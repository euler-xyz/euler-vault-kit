// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Errors} from "./Errors.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import "./types/Types.sol";

/// @title Cache
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Utilities for loading vault storage and updating it with interest accrued
contract Cache is Storage, Errors {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    // Returns an updated VaultCache
    // If different from VaultStorage, updates VaultStorage
    function updateVault() internal returns (VaultCache memory vaultCache) {
        if (initVaultCache(vaultCache)) {
            vaultStorage.lastInterestAccumulatorUpdate = vaultCache.lastInterestAccumulatorUpdate;
            vaultStorage.accumulatedFees = vaultCache.accumulatedFees;

            vaultStorage.totalShares = vaultCache.totalShares;
            vaultStorage.totalBorrows = vaultCache.totalBorrows;

            vaultStorage.interestAccumulator = vaultCache.interestAccumulator;
        }
    }

    // Returns an updated VaultCache
    function loadVault() internal view returns (VaultCache memory vaultCache) {
        initVaultCache(vaultCache);
    }

    // Takes a VaultCache struct, overwrites it with VaultStorage data and, if time has passed since MarkeStorage
    // was last updated, updates MarkeStorage.
    // Returns a VaultCache updated to this block.
    function initVaultCache(VaultCache memory vaultCache) private view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (vaultCache.asset, vaultCache.oracle, vaultCache.unitOfAccount) = ProxyUtils.metadata();

        // Storage loads

        vaultCache.lastInterestAccumulatorUpdate = vaultStorage.lastInterestAccumulatorUpdate;
        vaultCache.cash = vaultStorage.cash;
        vaultCache.supplyCap = vaultStorage.supplyCap.toUint();
        vaultCache.borrowCap = vaultStorage.borrowCap.toUint();
        vaultCache.hookedOps = vaultStorage.hookedOps;
        vaultCache.snapshotInitialized = vaultStorage.snapshotInitialized;

        vaultCache.totalShares = vaultStorage.totalShares;
        vaultCache.totalBorrows = vaultStorage.totalBorrows;

        vaultCache.accumulatedFees = vaultStorage.accumulatedFees;
        vaultCache.configFlags = vaultStorage.configFlags;

        vaultCache.interestAccumulator = vaultStorage.interestAccumulator;

        // Update interest accumulator and fees balance

        uint256 deltaT = block.timestamp - vaultCache.lastInterestAccumulatorUpdate;
        if (deltaT > 0) {
            dirty = true;

            // Compute new cache values. Use full precision for intermediate results.

            ConfigAmount interestFee = vaultStorage.interestFee;
            uint256 interestRate = vaultStorage.interestRate;

            uint256 newInterestAccumulator = vaultCache.interestAccumulator;

            unchecked {
                (uint256 multiplier, bool overflow) = RPow.rpow(interestRate + 1e27, deltaT, 1e27);

                // if exponentiation or accumulator update overflows, keep the old accumulator
                if (!overflow) {
                    uint256 intermediate = newInterestAccumulator * multiplier;
                    if (newInterestAccumulator == intermediate / multiplier) {
                        newInterestAccumulator = intermediate / 1e27;
                    }
                }
            }

            uint256 newTotalBorrows =
                vaultCache.totalBorrows.toUint() * newInterestAccumulator / vaultCache.interestAccumulator;
            uint256 newAccumulatedFees = vaultCache.accumulatedFees.toUint();
            uint256 newTotalShares = vaultCache.totalShares.toUint();
            uint256 feeAssets =
                interestFee.mulDiv(newTotalBorrows - vaultCache.totalBorrows.toUint(), 1 << INTERNAL_DEBT_PRECISION);

            if (feeAssets != 0) {
                uint256 newTotalAssets = vaultCache.cash.toUint() + OwedLib.toAssetsUpUint256(newTotalBorrows);
                newTotalShares = newTotalAssets * newTotalShares / (newTotalAssets - feeAssets);
                newAccumulatedFees += newTotalShares - vaultCache.totalShares.toUint();
            }

            // Store new values in vaultCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                vaultCache.totalBorrows = newTotalBorrows.toOwed();
                vaultCache.interestAccumulator = newInterestAccumulator;
                vaultCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);

                if (newTotalShares != vaultCache.totalShares.toUint() && newTotalShares <= MAX_SANE_AMOUNT) {
                    vaultCache.accumulatedFees = newAccumulatedFees.toShares();
                    vaultCache.totalShares = newTotalShares.toShares();
                }
            }
        }
    }

    function totalAssetsInternal(VaultCache memory vaultCache) internal pure returns (uint256) {
        // total assets can exceed Assets max amount (MAX_SANE_AMOUNT)
        return vaultCache.cash.toUint() + vaultCache.totalBorrows.toAssetsUp().toUint();
    }
}

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
    function updateVault() internal virtual returns (VaultCache memory vaultCache) {
        if (initVaultCache(vaultCache)) {
            vaultStorage.lastInterestAccumulatorUpdate = vaultCache.lastInterestAccumulatorUpdate;
            vaultStorage.accumulatedFees = vaultCache.accumulatedFees;

            vaultStorage.totalShares = vaultCache.totalShares;
            vaultStorage.totalBorrows = vaultCache.totalBorrows;

            vaultStorage.interestAccumulator = vaultCache.interestAccumulator;
        }
    }

    // Returns an updated VaultCache
    function loadVault() internal view virtual returns (VaultCache memory vaultCache) {
        initVaultCache(vaultCache);
    }

    // Takes a VaultCache struct, overwrites it with VaultStorage data and, if time has passed since MarkeStorage
    // was last updated, updates MarkeStorage.
    // Returns a boolean if the cache is different from storage. VaultCache param is updated to this block.
    function initVaultCache(VaultCache memory vaultCache) private view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (vaultCache.asset, vaultCache.oracle, vaultCache.unitOfAccount) = ProxyUtils.metadata();

        // Storage loads

        vaultCache.lastInterestAccumulatorUpdate = vaultStorage.lastInterestAccumulatorUpdate;
        vaultCache.cash = vaultStorage.cash;
        vaultCache.supplyCap = vaultStorage.supplyCap.resolve();
        vaultCache.borrowCap = vaultStorage.borrowCap.resolve();
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

            // Store new values in vaultCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                Owed newTotalBorrowsOwed = newTotalBorrows.toOwed();

                // record fees before totalBorrows update
                Owed feeOwed =
                    (newTotalBorrowsOwed - vaultCache.totalBorrows).mulDiv(interestFee.toUint16(), CONFIG_SCALE);

                vaultCache.totalBorrows = newTotalBorrowsOwed;
                vaultCache.interestAccumulator = newInterestAccumulator;
                vaultCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);

                // Charge fees on accrued interest

                if (!feeOwed.isZero()) {
                    // fee shares should be minted as if fees on interest were deposited as assets, after the rest of interest was added to total assets
                    // temporarily remove `feeOwed` from total borrows in the cache to mint fee shares at correct exchange rate
                    vaultCache.totalBorrows = vaultCache.totalBorrows.subUnchecked(feeOwed);
                    Shares newShares = feeOwed.toAssetsDown().toSharesDown(vaultCache);
                    vaultCache.totalBorrows = newTotalBorrowsOwed;

                    uint256 newTotalShares = vaultCache.totalShares.toUint() + newShares.toUint();
                    if (newTotalShares <= MAX_SANE_AMOUNT) {
                        vaultCache.totalShares = newTotalShares.toShares();
                        // accumulated fees <= total shares <= MAX_SANE_AMOUNT, because they are included in them
                        vaultCache.accumulatedFees = vaultCache.accumulatedFees + newShares;
                    }
                }
            }
        }
    }

    function totalAssetsInternal(VaultCache memory vaultCache) internal pure virtual returns (uint256) {
        // total assets can exceed Assets max amount (MAX_SANE_AMOUNT)
        return vaultCache.cash.toUint() + vaultCache.totalBorrows.toAssetsUp().toUint();
    }
}

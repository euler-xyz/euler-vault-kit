// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {VaultStorage} from "./VaultStorage.sol";
import {Errors} from "./Errors.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import "./types/Types.sol";

contract Cache is VaultStorage, Errors {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    // Returns an updated VaultCache
    // If different from VaultStorage, updates VaultStorage
    function updateVault() internal returns (VaultCache memory vaultCache) {
        if (initVaultCache(vaultCache)) {
            VaultData storage vs = vaultStorage();
            vs.lastInterestAccumulatorUpdate = vaultCache.lastInterestAccumulatorUpdate;
            vs.accumulatedFees = vaultCache.accumulatedFees;

            vs.totalShares = vaultCache.totalShares;
            vs.totalBorrows = vaultCache.totalBorrows;

            vs.interestAccumulator = vaultCache.interestAccumulator;
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
        VaultData storage vs = vaultStorage();
        vaultCache.lastInterestAccumulatorUpdate = vs.lastInterestAccumulatorUpdate;
        vaultCache.cash = vs.cash;
        vaultCache.supplyCap = vs.supplyCap.toUint();
        vaultCache.borrowCap = vs.borrowCap.toUint();
        vaultCache.disabledOps = vs.disabledOps;
        vaultCache.snapshotInitialized = vs.snapshotInitialized;

        vaultCache.totalShares = vs.totalShares;
        vaultCache.totalBorrows = vs.totalBorrows;

        vaultCache.accumulatedFees = vs.accumulatedFees;
        vaultCache.configFlags = vs.configFlags;

        vaultCache.interestAccumulator = vs.interestAccumulator;

        // Update interest accumulator and fees balance
        uint256 deltaT = block.timestamp - vaultCache.lastInterestAccumulatorUpdate;

        if (deltaT > 0) {
            dirty = true;

            if (vaultCache.disabledOps.isSet(OP_ACCRUE_INTEREST)) {
                vaultCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);
                return dirty;
            }

            // Compute new values. Use full precision for intermediate results.

            ConfigAmount interestFee = vs.interestFee;
            uint256 interestRate = vs.interestRate;

            uint256 newInterestAccumulator = vaultCache.interestAccumulator;

            unchecked {
                (uint256 multiplier, bool overflow) = RPow.rpow(interestRate + 1e27, deltaT, 1e27);

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
                uint256 newTotalAssets = vaultCache.cash.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION);
                newTotalShares = newTotalAssets * newTotalShares / (newTotalAssets - feeAssets);
                newAccumulatedFees += newTotalShares - vaultCache.totalShares.toUint();
            }

            // Store new values in vaultCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                vaultCache.totalBorrows = newTotalBorrows.toOwed();
                vaultCache.interestAccumulator = newInterestAccumulator;
                vaultCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);

                if (newTotalShares != Shares.unwrap(vaultCache.totalShares)) {
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

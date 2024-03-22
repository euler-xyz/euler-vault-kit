// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MarketStorage} from "./MarketStorage.sol";
import {Errors} from "./Errors.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import "./types/Types.sol";

contract Cache is MarketStorage, Errors {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    // Returns an updated MarketCache
    // If different from MarketStorage, updates MarketStorage
    function updateMarket() internal returns (MarketCache memory marketCache) {
        if (initMarketCache(marketCache)) {
            Market storage _marketStorage = marketStorage();
            _marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;
            _marketStorage.accumulatedFees = marketCache.accumulatedFees;

            _marketStorage.totalShares = marketCache.totalShares;
            _marketStorage.totalBorrows = marketCache.totalBorrows;

            _marketStorage.interestAccumulator = marketCache.interestAccumulator;
        }
    }

    // Returns an updated MarketCache
    function loadMarket() internal view returns (MarketCache memory marketCache) {
        initMarketCache(marketCache);
    }

    // Takes a MarketCache struct, overwrites it with MarketStorage data and, if time has passed since MarkeStorage
    // was last updated, updates MarkeStorage.
    // Returns a MarketCache updated to this block.
    function initMarketCache(MarketCache memory marketCache) private view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (marketCache.asset, marketCache.oracle, marketCache.unitOfAccount) = ProxyUtils.metadata();

        // Storage loads
        Market storage _marketStorage = marketStorage();
        marketCache.lastInterestAccumulatorUpdate = _marketStorage.lastInterestAccumulatorUpdate;
        marketCache.cash = _marketStorage.cash;
        marketCache.supplyCap = _marketStorage.supplyCap.toUint();
        marketCache.borrowCap = _marketStorage.borrowCap.toUint();
        marketCache.disabledOps = _marketStorage.disabledOps;
        marketCache.snapshotInitialized = _marketStorage.snapshotInitialized;

        marketCache.totalShares = _marketStorage.totalShares;
        marketCache.totalBorrows = _marketStorage.totalBorrows;

        marketCache.accumulatedFees = _marketStorage.accumulatedFees;
        marketCache.configFlags = _marketStorage.configFlags;

        marketCache.interestAccumulator = _marketStorage.interestAccumulator;

        // Update interest accumulator and fees balance
        uint256 deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;

        if (deltaT > 0) {
            dirty = true;

            if (marketCache.disabledOps.isSet(OP_ACCRUE_INTEREST)) {
                marketCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);
                return dirty;
            }

            // Compute new values. Use full precision for intermediate results.

            ConfigAmount interestFee = _marketStorage.interestFee;
            uint256 interestRate = _marketStorage.interestRate;

            uint256 newInterestAccumulator = marketCache.interestAccumulator;

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
                marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;
            uint256 newAccumulatedFees = marketCache.accumulatedFees.toUint();
            uint256 newTotalShares = marketCache.totalShares.toUint();
            uint256 feeAssets =
                interestFee.mulDiv(newTotalBorrows - marketCache.totalBorrows.toUint(), 1 << INTERNAL_DEBT_PRECISION);

            if (feeAssets != 0) {
                uint256 newTotalAssets = marketCache.cash.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION);
                newTotalShares = newTotalAssets * newTotalShares / (newTotalAssets - feeAssets);
                newAccumulatedFees += newTotalShares - marketCache.totalShares.toUint();
            }

            // Store new values in marketCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint48(block.timestamp);

                if (newTotalShares != Shares.unwrap(marketCache.totalShares)) {
                    marketCache.accumulatedFees = newAccumulatedFees.toShares();
                    marketCache.totalShares = newTotalShares.toShares();
                }
            }
        }
    }

    function totalAssetsInternal(MarketCache memory marketCache) internal pure returns (uint256) {
        // total assets can exceed Assets max amount (MAX_SANE_AMOUNT)
        return marketCache.cash.toUint() + marketCache.totalBorrows.toAssetsUp().toUint();
    }
}

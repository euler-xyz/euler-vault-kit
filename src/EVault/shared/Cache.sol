// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Errors} from "./Errors.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {ProxyUtils} from "./lib/ProxyUtils.sol";

import "./types/Types.sol";

contract Cache is Storage, Errors {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    function updateMarket() internal returns (MarketCache memory marketCache) {
        if (initMarketCache(marketCache)) {
            marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;
            marketStorage.feesBalance = marketCache.feesBalance;

            marketStorage.totalShares = marketCache.totalShares;
            marketStorage.totalBorrows = marketCache.totalBorrows;

            marketStorage.interestAccumulator = marketCache.interestAccumulator;
        }
    }

    function loadMarket() internal view returns (MarketCache memory marketCache) {
        initMarketCache(marketCache);
    }

    function initMarketCache(MarketCache memory marketCache) private view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (marketCache.asset, marketCache.oracle, marketCache.unitOfAccount) = ProxyUtils.metadata();

        // Storage loads

        marketCache.lastInterestAccumulatorUpdate = marketStorage.lastInterestAccumulatorUpdate;
        marketCache.poolSize = marketStorage.poolSize;
        marketCache.supplyCap = marketStorage.supplyCap.toUint();
        marketCache.borrowCap = marketStorage.borrowCap.toUint();
        marketCache.disabledOps = marketStorage.disabledOps;
        marketCache.snapshotInitialized = marketStorage.snapshotInitialized;

        marketCache.totalShares = marketStorage.totalShares;
        marketCache.totalBorrows = marketStorage.totalBorrows;

        marketCache.feesBalance = marketStorage.feesBalance;

        marketCache.interestAccumulator = marketStorage.interestAccumulator;

        // Update interest  accumulator and fees balance

        if (block.timestamp != marketCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            // Compute new values. Use full precision for intermediate results.

            uint16 interestFee = marketStorage.interestFee;
            uint256 interestRate = marketStorage.interestRate;

            uint256 deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;
            uint256 newInterestAccumulator =
                (RPow.rpow(interestRate + 1e27, deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;

            uint256 newTotalBorrows =
                marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;
            uint256 newFeesBalance = marketCache.feesBalance.toUint();
            uint256 newTotalShares = marketCache.totalShares.toUint();

            uint256 feeAssets = (newTotalBorrows - marketCache.totalBorrows.toUint()) * interestFee
                / (CONFIG_SCALE << INTERNAL_DEBT_PRECISION);

            if (feeAssets != 0) {
                uint256 poolAssets = marketCache.poolSize.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION);
                newTotalShares = poolAssets * newTotalShares / (poolAssets - feeAssets);
                newFeesBalance += newTotalShares - marketCache.totalShares.toUint();
            }

            // Store new values in marketCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalShares != Shares.unwrap(marketCache.totalShares)) {
                    marketCache.feesBalance = newFeesBalance.toShares();
                    marketCache.totalShares = newTotalShares.toShares();
                }
            }
        }
    }

    function totalAssetsInternal(MarketCache memory marketCache) internal pure returns (uint256) {
        // total assets can exceed Assets max amount (MAX_SANE_AMOUNT)
        return marketCache.poolSize.toUint() + marketCache.totalBorrows.toAssetsUp().toUint();
    }
}

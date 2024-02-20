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

        (marketCache.asset) = ProxyUtils.metadata();

        // Storage loads

        marketCache.lastInterestAccumulatorUpdate = marketStorage.lastInterestAccumulatorUpdate;
        marketCache.poolSize = marketStorage.poolSize;
        marketCache.feesBalance = marketStorage.feesBalance;

        marketCache.totalShares = marketStorage.totalShares;
        marketCache.totalBorrows = marketStorage.totalBorrows;

        marketCache.interestAccumulator = marketStorage.interestAccumulator;

        // Update interest  accumulator and fees balance

        if (block.timestamp != marketCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            // Compute new values. Use full precision for intermediate results.

            uint72 interestRate = marketStorage.interestRate;
            uint16 interestFee = marketConfig.interestFee;

            uint256 deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;
            uint256 newInterestAccumulator =
                (RPow.rpow(uint256(interestRate) + 1e27, deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;

            uint256 newTotalBorrows =
                marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;
            uint256 newFeesBalance = marketCache.feesBalance.toUint();
            uint256 newTotalShares = marketCache.totalShares.toUint();

            uint256 feeAmount = (newTotalBorrows - marketCache.totalBorrows.toUint()) * interestFee
                / (INTEREST_FEE_SCALE << INTERNAL_DEBT_PRECISION);

            if (feeAmount != 0) {
                uint256 poolAssets = marketCache.poolSize.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION);
                newTotalShares = poolAssets * newTotalShares / (poolAssets - feeAmount);
                newFeesBalance += newTotalShares - marketCache.totalShares.toUint();
            }

            // Store new values in marketCache, only if no overflows will occur

            if (
                newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT
                    && newFeesBalance <= MAX_SANE_SMALL_AMOUNT
            ) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalShares != Shares.unwrap(marketCache.totalShares)) {
                    marketCache.feesBalance = newFeesBalance.toFees();
                    marketCache.totalShares = newTotalShares.toShares();
                }
            }
        }
    }
}

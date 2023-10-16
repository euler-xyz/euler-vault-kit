// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Errors} from "./Errors.sol";
import {RPow} from "./lib/RPow.sol";
import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";

import "./types/Types.sol";

contract Cache is Storage, Errors {
    using TypesLib for uint;
    using SafeERC20Lib for IERC20;

    function proxyMetadata() internal pure returns (IERC20 marketAsset, IRiskManager riskManager) {
        assembly {
            marketAsset := shr(96, calldataload(sub(calldatasize(), 40)))
            riskManager := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    // MarketCache

    function initMarketCache(MarketCache memory marketCache) internal view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (marketCache.asset, marketCache.riskManager) = proxyMetadata();

        // Storage loads

        marketCache.lastInterestAccumulatorUpdate = marketStorage.lastInterestAccumulatorUpdate;
        marketCache.feesBalance = marketStorage.feesBalance;
        marketCache.interestRate = marketStorage.interestRate;
        marketCache.interestFee = marketStorage.interestFee;

        marketCache.totalBalances = marketStorage.totalBalances;
        marketCache.totalBorrows = marketStorage.totalBorrows;

        marketCache.interestAccumulator = marketStorage.interestAccumulator;

        // Derived state

        uint poolSize = marketCache.asset.callBalanceOf(address(this));
        marketCache.poolSize = (poolSize <= MAX_SANE_AMOUNT ? poolSize : 0).toAssets();

        // Update interest  accumulator and fees balance 

        if (block.timestamp != marketCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            // Compute new values. Use full precision for intermediate results.

            uint deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;
            uint newInterestAccumulator = (RPow.rpow(uint(int(marketCache.interestRate) + 1e27), deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;

            uint newTotalBorrows = marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;
            uint newFeesBalance = marketCache.feesBalance.toUint();
            uint newTotalBalances = marketCache.totalBalances.toUint();

            uint feeAmount = (newTotalBorrows - marketCache.totalBorrows.toUint())
                               * marketCache.interestFee
                               / (INTEREST_FEE_SCALE * INTERNAL_DEBT_PRECISION);

            if (feeAmount != 0) {
                uint poolAssets = marketCache.poolSize.toUint() + (newTotalBorrows / INTERNAL_DEBT_PRECISION);
                newTotalBalances = poolAssets * newTotalBalances / (poolAssets - feeAmount);
                newFeesBalance += newTotalBalances - marketCache.totalBalances.toUint();
            }

            // Store new values in marketCache, only if no overflows will occur

            if (newTotalBalances <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT && newFeesBalance <= MAX_SANE_SMALL_AMOUNT) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalBalances != Shares.unwrap(marketCache.totalBalances)) {
                    marketCache.feesBalance = newFeesBalance.toFees();
                    marketCache.totalBalances = newTotalBalances.toShares();
                }
            }
        }
    }

    function loadAndUpdateMarket() internal returns (MarketCache memory marketCache) {
        if (initMarketCache(marketCache)) {
            marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;
            marketStorage.feesBalance = marketCache.feesBalance;

            marketStorage.totalBalances = marketCache.totalBalances;
            marketStorage.totalBorrows = marketCache.totalBorrows;

            marketStorage.interestAccumulator = marketCache.interestAccumulator;

        }
    }

    function loadMarketNonReentrant() internal view returns (MarketCache memory marketCache) {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();
        initMarketCache(marketCache);
    }

    function loadMarket() internal view returns (MarketCache memory marketCache) {
        initMarketCache(marketCache);
    }
}
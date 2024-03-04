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

    // Returns an updated MarketCache
    // If different from MarketStorage, updates MarketStorage
    function updateMarket() internal returns (MarketCache memory marketCache) {
        if (initMarketCache(marketCache)) {
            marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;
            marketStorage.feesBalance = marketCache.feesBalance;

            marketStorage.totalShares = marketCache.totalShares;
            marketStorage.totalBorrows = marketCache.totalBorrows;

            marketStorage.interestAccumulator = marketCache.interestAccumulator;
        }
    }

    // Returns an updated MarketCache 
    function loadMarket() internal view returns (MarketCache memory marketCache) {
        initMarketCache(marketCache);
    }

    // Takes a MarketCache struct, overwrites it with MarketStorage data and, if time has passed since MarkeStorage
    // was last updated, updates MarketCache.
    // Returns a MarketCache updated to this block.
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

            uint16 interestFee = marketStorage.interestFee; // r: Interest accrued by debt --- alcueca: To avoid accidental overflows you should use uint256 for all temporary variables
            uint256 interestRate = marketStorage.interestRate; // f: Fee charged on the accrued interest as newly minted shares, accounted for in marketCache.feesBalance

            uint256 deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;
            uint256 newInterestAccumulator =
                (RPow.rpow(interestRate + 1e27, deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;  // a' = a * (r+1)^Δt

            uint256 newTotalBorrows =
                marketCache.totalBorrows.toUint() * newInterestAccumulator / marketCache.interestAccumulator;  // B' = B * (a' / a)
            uint256 newFeeShares = marketCache.feesBalance.toUint(); // feesBalance should be renamed to feeShares
            uint256 newTotalShares = marketCache.totalShares.toUint();

            uint256 feeAssets = (newTotalBorrows - marketCache.totalBorrows.toUint()) * interestFee  // f = (B' - B) * i
                / (CONFIG_SCALE << INTERNAL_DEBT_PRECISION);

            if (feeAssets != 0) {
                uint256 poolAssets = marketCache.poolSize.toUint() + (newTotalBorrows >> INTERNAL_DEBT_PRECISION); // alcueca: poolSize is the assets held by the Vault (rename to vaultAssets), poolAssets is assets held + debt issued (rename to vaultAssetsAndBorrows). We scale newTotalBorrows from debt to asset units.
                newTotalShares = poolAssets * newTotalShares / (poolAssets - feeAssets); // alcueca: We want to issue new shares worth feeAssets, which proportionally decreases the assets that each share is worth.
                newFeeShares += newTotalShares - marketCache.totalShares.toUint();
            }

            // Store new values in marketCache, only if no overflows will occur. Fees are not larger than total shares, since they are included in them.

            if (newTotalShares <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                marketCache.totalBorrows = newTotalBorrows.toOwed();
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalShares != Shares.unwrap(marketCache.totalShares)) {
                    marketCache.feesBalance = newFeeShares.toShares();
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

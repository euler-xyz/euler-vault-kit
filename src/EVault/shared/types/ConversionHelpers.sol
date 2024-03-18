// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MarketCache} from "./MarketCache.sol";

// virtual deposit used in conversions between shares and assets, serving as exchange rate manipulation mitigation
uint256 constant VIRTUAL_DEPOSIT_AMOUNT = 1e6;

function conversionTotals(MarketCache memory marketCache) pure returns (uint256 totalAssets, uint256 totalShares) {
    unchecked {
        totalAssets =
            marketCache.cash.toUint() + marketCache.totalBorrows.toAssetsUp().toUint() + VIRTUAL_DEPOSIT_AMOUNT;
        totalShares = marketCache.totalShares.toUint() + VIRTUAL_DEPOSIT_AMOUNT;
    }
}

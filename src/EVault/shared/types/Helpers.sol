// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./MarketCache.sol";

function totals(MarketCache memory marketCache) pure returns (uint256 totalAssets, uint256 totalBalances) {
    unchecked {
        totalAssets = marketCache.poolSize.toUint() + marketCache.totalBorrows.toUintAssetsDown();
    }
    totalBalances = marketCache.totalBalances.toUint();
}

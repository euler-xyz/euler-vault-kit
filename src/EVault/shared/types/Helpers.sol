// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./MarketCache.sol";
import "../Constants.sol";

function totals(MarketCache memory marketCache) pure returns (uint256 totalAssets, uint256 totalShares) {
    unchecked {
        totalAssets =
            marketCache.poolSize.toUint() + marketCache.totalBorrows.toAssetsUp().toUint() + VIRTUAL_DEPOSIT_AMOUNT;
    }
    // review: why is it not unchecked?
    totalShares = marketCache.totalShares.toUint() + VIRTUAL_DEPOSIT_AMOUNT;
}

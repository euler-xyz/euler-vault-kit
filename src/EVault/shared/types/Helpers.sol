// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./MarketCache.sol";

function totalsVirtual(MarketCache memory marketCache) pure returns (uint totalAssets, uint totalBalances) {
    // adding 1 wei virtual asset and share. See https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack
    totalAssets = marketCache.poolSize.toUint() + marketCache.totalBorrows.toUintAssetsDown() + 1;
    totalBalances = marketCache.totalBalances.toUint() + 1;
}

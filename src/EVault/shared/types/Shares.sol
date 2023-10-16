// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "./MarketCache.sol";
import "./Helpers.sol";


library SharesLib {
    function toUint(Shares self) pure internal returns (uint) {
        return Shares.unwrap(self);
    }

    function isZero(Shares self) pure internal returns (bool) {
        return Shares.unwrap(self) == 0;
    }

    function toAssetsDown(Shares amount, MarketCache memory marketCache) pure internal returns (Assets) {
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return TypesLib.toAssets(
            amount.toUint() * totalAssets / totalBalances
        );
    }

    function toAssetsUp(Shares amount, MarketCache memory marketCache) pure internal returns (Assets) {
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return TypesLib.toAssets(
            (amount.toUint() * totalAssets / totalBalances) + (mulmod(amount.toUint(), totalAssets, totalBalances) != 0 ? 1 : 0)
        );
    }
}

function addShares(Shares a, Shares b) pure returns (Shares) {
    return TypesLib.toShares(uint(Shares.unwrap(a)) + uint(Shares.unwrap(b)));
}

function subShares(Shares a, Shares b) pure returns (Shares) {
    return Shares.wrap((Shares.unwrap(a) - Shares.unwrap(b)));
}

function eqShares(Shares a, Shares b) pure returns (bool) {
    return Shares.unwrap(a) == Shares.unwrap(b);
}

function neqShares(Shares a, Shares b) pure returns (bool) {
    return Shares.unwrap(a) != Shares.unwrap(b);
}

function gtShares(Shares a, Shares b) pure returns (bool) {
    return Shares.unwrap(a) > Shares.unwrap(b);
}

function ltShares(Shares a, Shares b) pure returns (bool) {
    return Shares.unwrap(a) < Shares.unwrap(b);
}

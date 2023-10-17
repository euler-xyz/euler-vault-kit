// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";
import "./MarketCache.sol";
import "./Helpers.sol";


library AssetsLib {
    function toUint(Assets self) pure internal returns (uint) {
        return Assets.unwrap(self);
    }

    function isZero(Assets self) pure internal returns (bool) {
        return Assets.unwrap(self) == 0;
    }

    function toSharesDown(Assets amount, MarketCache memory marketCache) pure internal returns (Shares) {
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return TypesLib.toShares(
            amount.toUint() * totalBalances / totalAssets
        );
    }

    // Exclude the asset amount from the pool size when converting to shares. It's used to get the shares amount after the deposit
    function toSharesDownExclusive(Assets amount, MarketCache memory marketCache) pure internal returns (Shares) {
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return TypesLib.toShares(
            amount.toUint() * totalBalances / (totalAssets - amount.toUint())
        );
    }

    function toSharesUp(Assets amount, MarketCache memory marketCache) pure internal returns (Shares) {
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return TypesLib.toShares(
            (amount.toUint() * totalBalances / totalAssets) + (mulmod(amount.toUint(), totalBalances, totalAssets) != 0 ? 1 : 0)
        );
    }

    function toOwed(Assets self) pure internal returns (Owed) {
        return TypesLib.toOwed(
            uint(Assets.unwrap(self)) * INTERNAL_DEBT_PRECISION
        );
    }
}

function addAssets(Assets a, Assets b) pure returns (Assets) {
    return TypesLib.toAssets(uint(Assets.unwrap(a)) + uint(Assets.unwrap(b)));
}

function subAssets(Assets a, Assets b) pure returns (Assets) {
    return Assets.wrap((Assets.unwrap(a) - Assets.unwrap(b)));
}

function eqAssets(Assets a, Assets b) pure returns (bool) {
    return Assets.unwrap(a) == Assets.unwrap(b);
}

function neqAssets(Assets a, Assets b) pure returns (bool) {
    return Assets.unwrap(a) != Assets.unwrap(b);
}

function gtAssets(Assets a, Assets b) pure returns (bool) {
    return Assets.unwrap(a) > Assets.unwrap(b);
}

function ltAssets(Assets a, Assets b) pure returns (bool) {
    return Assets.unwrap(a) < Assets.unwrap(b);
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Assets, Shares, Owed, TypesLib} from "./Types.sol";
import {VaultCache} from "./VaultCache.sol";
import "../Constants.sol";
import "./ConversionHelpers.sol";

library AssetsLib {
    function toUint(Assets self) internal pure returns (uint256) {
        return Assets.unwrap(self);
    }

    function isZero(Assets self) internal pure returns (bool) {
        return Assets.unwrap(self) == 0;
    }

    function toSharesDown(Assets amount, VaultCache memory vaultCache) internal pure returns (Shares) {
        (uint256 totalAssets, uint256 totalShares) = conversionTotals(vaultCache);
        unchecked {
            return TypesLib.toShares(amount.toUint() * totalShares / totalAssets);
        }
    }

    function toSharesUp(Assets amount, VaultCache memory vaultCache) internal pure returns (Shares) {
        (uint256 totalAssets, uint256 totalShares) = conversionTotals(vaultCache);
        unchecked {
            return TypesLib.toShares((amount.toUint() * totalShares + (totalAssets - 1)) / totalAssets);
        }
    }

    function toOwed(Assets self) internal pure returns (Owed) {
        unchecked {
            return TypesLib.toOwed(uint256(Assets.unwrap(self)) << INTERNAL_DEBT_PRECISION);
        }
    }
}

function addAssets(Assets a, Assets b) pure returns (Assets) {
    return TypesLib.toAssets(uint256(Assets.unwrap(a)) + uint256(Assets.unwrap(b)));
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

function lteAssets(Assets a, Assets b) pure returns (bool) {
    return Assets.unwrap(a) <= Assets.unwrap(b);
}

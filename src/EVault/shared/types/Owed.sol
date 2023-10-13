// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";

library OwedLib {
    function toUint(Owed self) pure internal returns (uint) {
        return Owed.unwrap(self);
    }

    function toAssetsDown(Owed amount) internal pure returns (Assets) {
        if (Owed.unwrap(amount) == 0) return Assets.wrap(0);
        return TypesLib.toAssets(
            Owed.unwrap(amount) / INTERNAL_DEBT_PRECISION
        );
    }

    function toAssetsUp(Owed amount) internal pure returns (Assets) {
        if (Owed.unwrap(amount) == 0) return Assets.wrap(0);
        uint assets;
        unchecked {
            assets = (uint(Owed.unwrap(amount)) + INTERNAL_DEBT_PRECISION - 1) / INTERNAL_DEBT_PRECISION;
        }
        return TypesLib.toAssets(assets);
    }

    function isDust(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) < INTERNAL_DEBT_PRECISION;
    }

    function isZero(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) == 0;
    }
}

function addOwed(Owed a, Owed b) pure returns (Owed) {
    return TypesLib.toOwed(uint(Owed.unwrap(a)) + uint(Owed.unwrap(b)));
}

function subOwed(Owed a, Owed b) pure returns (Owed) {
    return Owed.wrap((Owed.unwrap(a) - Owed.unwrap(b)));
}

function eqOwed(Owed a, Owed b) pure returns (bool) {
    return Owed.unwrap(a) == Owed.unwrap(b);
}

function neqOwed(Owed a, Owed b) pure returns (bool) {
    return Owed.unwrap(a) != Owed.unwrap(b);
}

function gtOwed(Owed a, Owed b) pure returns (bool) {
    return Owed.unwrap(a) > Owed.unwrap(b);
}

function ltOwed(Owed a, Owed b) pure returns (bool) {
    return Owed.unwrap(a) < Owed.unwrap(b);
}

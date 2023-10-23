// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";

library OwedLib {
    function toUint(Owed self) pure internal returns (uint) {
        return Owed.unwrap(self);
    }

    function toUintAssetsDown(Owed amount) internal pure returns (uint) {
        if (Owed.unwrap(amount) == 0) return 0;
        return Owed.unwrap(amount) / INTERNAL_DEBT_PRECISION;
    }

    function toAssetsDown(Owed amount) internal pure returns (Assets) {
        return TypesLib.toAssets(toUintAssetsDown(amount));
    }

    function toUintAssetsUp(Owed amount) internal pure returns (uint) {
        if (Owed.unwrap(amount) == 0) return 0;
        uint assets;
        unchecked {
            assets = (uint(Owed.unwrap(amount)) + INTERNAL_DEBT_PRECISION - 1) / INTERNAL_DEBT_PRECISION;
        }
        return assets;
    }

    function toAssetsUp(Owed amount) internal pure returns (Assets) {
        return TypesLib.toAssets(toUintAssetsUp(amount));
    }

    function isDust(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) < INTERNAL_DEBT_PRECISION;
    }

    function isZero(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) == 0;
    }

    function mulDiv(Owed self, uint multiplier, uint divisor) pure internal returns (Owed) {
        return TypesLib.toOwed(uint(Owed.unwrap(self)) * multiplier / divisor);
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

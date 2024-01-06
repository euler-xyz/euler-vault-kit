// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";

import "hardhat/console.sol";

library OwedLib {
    function toUint(Owed self) internal pure returns (uint256) {
        return Owed.unwrap(self);
    }

    function toUintAssetsDown(Owed amount) internal pure returns (uint256) {
        if (Owed.unwrap(amount) == 0) return 0;

        unchecked {
            return Owed.unwrap(amount) / INTERNAL_DEBT_PRECISION;
        }
    }

    function toUintAssetsUp(Owed amount) internal pure returns (uint256) {
        if (Owed.unwrap(amount) == 0) return 0;

        unchecked {
            return (uint256(Owed.unwrap(amount)) + INTERNAL_DEBT_PRECISION - 1) / INTERNAL_DEBT_PRECISION;
        }
    }

    function toOwedAssetsSnapshot(Owed amount) internal pure returns (OwedAssetsSnapshot) {
        return OwedAssetsSnapshot.wrap(uint120(toUintAssetsUp(amount)));
    }

    function isDust(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) < INTERNAL_DEBT_PRECISION;
    }

    function isZero(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) == 0;
    }

    function mulDiv(Owed self, uint256 multiplier, uint256 divisor) internal pure returns (Owed) {
        return TypesLib.toOwed(uint256(Owed.unwrap(self)) * multiplier / divisor);
    }
}

function addOwed(Owed a, Owed b) pure returns (Owed) {
    return TypesLib.toOwed(uint256(Owed.unwrap(a)) + uint256(Owed.unwrap(b)));
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

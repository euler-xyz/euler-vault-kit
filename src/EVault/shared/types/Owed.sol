// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";

library OwedLib {
    function toUint(Owed self) internal pure returns (uint256) {
        return Owed.unwrap(self);
    }

    function toAssetsUp(Owed amount) internal pure returns (Assets) {
        if (Owed.unwrap(amount) == 0) return Assets.wrap(0);

        unchecked {
            return TypesLib.toAssets(
                (uint256(Owed.unwrap(amount)) + (1 << INTERNAL_DEBT_PRECISION) - 1) >> INTERNAL_DEBT_PRECISION
            );
        }
    }

    function isDust(Owed self) internal pure returns (bool) {
        return Owed.unwrap(self) < (1 << INTERNAL_DEBT_PRECISION); // less than a minimum representable internal debt amount
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

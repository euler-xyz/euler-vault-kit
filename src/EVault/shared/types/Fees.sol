// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "./MarketCache.sol";
import "./Shares.sol";

library FeesLib {
    function toUint(Fees self) pure internal returns (uint) {
        return Fees.unwrap(self);
    }

    function toAssetsDown(Fees self, MarketCache memory marketCache) pure internal returns (Assets) {
        return SharesLib.toAssetsDown(TypesLib.toShares(Fees.unwrap(self)), marketCache);
    }

    function toShares(Fees self) pure internal returns (Shares) {
        return Shares.wrap(Fees.unwrap(self));
    }

    function mulDiv(Fees self, uint multiplier, uint divisor) pure internal returns (Fees) {
        return TypesLib.toFees(uint(Fees.unwrap(self)) * multiplier / divisor);
    }
}

function addFees(Fees a, Fees b) pure returns (Fees) {
    return TypesLib.toFees(uint(Fees.unwrap(a)) + uint(Fees.unwrap(b)));
}

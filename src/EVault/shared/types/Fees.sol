// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "./MarketCache.sol";
import "./Shares.sol";

library FeesLib {
    function toUint(Fees self) internal pure returns (uint256) {
        return Fees.unwrap(self);
    }

    function toAssetsDown(Fees self, MarketCache memory marketCache) internal pure returns (Assets) {
        return SharesLib.toAssetsDown(TypesLib.toShares(Fees.unwrap(self)), marketCache);
    }

    function toShares(Fees self) internal pure returns (Shares) {
        return Shares.wrap(Fees.unwrap(self));
    }

    function mulDiv(Fees self, uint256 multiplier, uint256 divisor) internal pure returns (Fees) {
        return TypesLib.toFees(uint256(Fees.unwrap(self)) * multiplier / divisor);
    }
}

function addFees(Fees a, Fees b) pure returns (Fees) {
    return TypesLib.toFees(uint256(Fees.unwrap(a)) + uint256(Fees.unwrap(b)));
}

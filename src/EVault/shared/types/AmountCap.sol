// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";
import "../Constants.sol";
import "../Errors.sol";

// AmountCaps are 16-bit decimal floating point values:
// * The least significant 6 bits are the exponent
// * The most significant 10 bits are the mantissa, scaled by 100
// * The special value of 0 means no limit (MAX_SANE_AMOUNT)
//   * This is so that uninitialised storage implies no limit
//   * For an actual cap value of 0, use a zero mantissa and non-zero exponent

library AmountCapLib {
    // FIXME: should this actually return an Amount type?
    function toAmount(AmountCap self) internal pure returns (uint256) {
        uint256 amountCap = AmountCap.unwrap(self);

        if (amountCap == 0) return MAX_SANE_AMOUNT;

        unchecked {
            // Cannot overflow because this is less than 2**256:
            //   10**(2**6 - 1) * (2**10 - 1) = 1.023e+66

            return 10**(amountCap & 63) * (amountCap >> 6) / 100;
        }
    }

    function validate(AmountCap self) internal pure returns (AmountCap) {
        if (self.toAmount() > MAX_SANE_AMOUNT) revert Errors.RM_InvalidAmountCap();
        return self;
    }

    function toUint16(AmountCap self) internal pure returns (uint16) {
        return AmountCap.unwrap(self);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ConfigAmount} from "./Types.sol";
import {Errors} from "../Errors.sol";
import "../Constants.sol";

/// @title ConfigAmountLib
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Library for `ConfigAmount` custom type
/// @dev ConfigAmounts are floating point values encoded in 16 bits with a 1e4 precision.
/// @dev The type is used to store protocol configuration values.
library ConfigAmountLib {
    // note assuming arithmetic checks are already performed
    function mulDiv(ConfigAmount self, uint256 multiplier, uint256 divisor) internal pure returns (uint256) {
        unchecked {
            return uint256(self.toUint16()) * multiplier / (1e4 * divisor);
        }
    }

    // note assuming arithmetic checks are already performed
    function mul(ConfigAmount self, uint256 multiplier) internal pure returns (uint256) {
        unchecked {
            return uint256(self.toUint16()) * multiplier / 1e4;
        }
    }

    // note assuming arithmetic checks are already performed
    function mulInv(ConfigAmount self, uint256 multiplier) internal pure returns (uint256) {
        unchecked {
            return 1e4 * multiplier / uint256(self.toUint16());
        }
    }

    function isZero(ConfigAmount self) internal pure returns (bool) {
        return self.toUint16() == 0;
    }

    function toUint16(ConfigAmount self) internal pure returns (uint16) {
        return ConfigAmount.unwrap(self);
    }

    function validate(uint256 amount) internal pure {
        if (amount > 1e4) revert Errors.E_InvalidConfigAmount();
    }
}

function gtConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (bool) {
    unchecked {
        return a.toUint16() > b.toUint16();
    }
}

function gteConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (bool) {
    unchecked {
        return a.toUint16() >= b.toUint16();
    }
}

function ltConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (bool) {
    unchecked {
        return a.toUint16() < b.toUint16();
    }
}

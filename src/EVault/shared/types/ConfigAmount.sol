// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ConfigAmount} from "./Types.sol";
import "../Constants.sol"; 

// ConfigAmounts are floating point values encoded in 16 bits with a CONFIG_SCALE precision (60 000).
// The type is used to store protocol configuration values.

uint256 constant CONFIGAMOUNT_1_PERCENT = CONFIG_SCALE * 1 / 100;
uint256 constant CONFIGAMOUNT_50_PERCENT = CONFIG_SCALE * 50 / 100;


library ConfigAmountLib {
    // note assuming arithmetic checks are already performed
    function mulDiv(ConfigAmount self, uint256 multiplier, uint256 divisor) internal pure returns (uint256) {
        unchecked {
            return uint256(self.toUint16()) * multiplier / (CONFIG_SCALE * divisor);
        }
    }

    // note assuming arithmetic checks are already performed
    function mul(ConfigAmount self, uint256 multiplier) internal pure returns (uint256) {
        unchecked {
            return uint256(self.toUint16()) * multiplier / CONFIG_SCALE;
        }
    }

    function toUint16(ConfigAmount self) internal pure returns (uint16) {
        return ConfigAmount.unwrap(self);
    }

    function isZero(ConfigAmount self) internal pure returns (bool) {
        return self.toUint16() == 0;
    }
}

// note assuming arithmetic checks are already performed
function addConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (ConfigAmount) {
    unchecked {
        return ConfigAmount.wrap(a.toUint16() + b.toUint16());
    }
}

// note assuming arithmetic checks are already performed
function subConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (ConfigAmount) {
    unchecked {
        return ConfigAmount.wrap(a.toUint16() - b.toUint16());
    }
}

function gtConfigAmount(ConfigAmount a, ConfigAmount b) pure returns (bool) {
    unchecked {
        return a.toUint16() > b.toUint16();
    }
}
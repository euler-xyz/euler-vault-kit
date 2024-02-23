// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";

library DisabledOpsLib {
    function get(DisabledOps self, uint32 bitMask) internal pure returns (bool) {
        return (DisabledOps.unwrap(self) & bitMask) != 0;
    }

    function toUint32(DisabledOps self) internal pure returns (uint32) {
        return DisabledOps.unwrap(self);
    }
}

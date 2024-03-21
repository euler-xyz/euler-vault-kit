// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Flags} from "./Types.sol";

library FlagsLib {
    function isSet(Flags self, uint32 bitMask) internal pure returns (bool) {
        return (Flags.unwrap(self) & bitMask) != 0;
    }

    function isNotSet(Flags self, uint32 bitMask) internal pure returns (bool) {
        return (Flags.unwrap(self) & bitMask) == 0;
    }

    function toUint32(Flags self) internal pure returns (uint32) {
        return Flags.unwrap(self);
    }
}

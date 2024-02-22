// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./Types.sol";

library BitFieldLib {
    function set(BitField self, uint32 bitMask) internal pure returns (BitField) {
        return BitField.wrap(BitField.unwrap(self) | bitMask);
    }

    function clear(BitField self, uint32 bitMask) internal pure returns (BitField) {
        return BitField.wrap(BitField.unwrap(self) & ~bitMask);
    }

    function get(BitField self, uint32 bitMask) internal pure returns (bool) {
        return (BitField.unwrap(self) & bitMask) != 0;
    }

    function toUint32(BitField self) internal pure returns (uint32) {
        return BitField.unwrap(self);
    }
}

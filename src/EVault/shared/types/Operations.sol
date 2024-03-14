// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Operations} from "./Types.sol";

library OperationsLib {
    function get(Operations self, uint32 bitMask) internal pure returns (bool) {
        return (Operations.unwrap(self) & bitMask) != 0;
    }

    function toUint32(Operations self) internal pure returns (uint32) {
        return Operations.unwrap(self);
    }
}

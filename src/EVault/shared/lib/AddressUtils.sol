// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../Errors.sol";

library AddressUtils {
    function checkContract(address addr) internal view returns (address) {
        if (addr.code.length == 0) revert Errors.E_BadAddress();

        return addr;
    }
}

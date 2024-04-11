// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../Errors.sol";

function validateAddress(address addr) pure returns (address) {
    if (addr == address(0)) revert Errors.E_BadAddress();

    return addr;
}

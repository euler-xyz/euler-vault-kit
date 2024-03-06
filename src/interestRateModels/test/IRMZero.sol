// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../BaseIRM.sol";

contract IRMZero is BaseIRM {
    function computeInterestRateImpl(address, address, uint32) internal pure override returns (uint256) {
        return 0;
    }
}

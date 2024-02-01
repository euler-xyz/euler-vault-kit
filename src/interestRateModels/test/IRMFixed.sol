// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../BaseIRM.sol";

contract IRMFixed is BaseIRM {
    constructor(bytes32 _gitCommit) BaseIRM(_gitCommit) {}

    function computeInterestRateImpl(address, address, uint32) internal pure override returns (uint72) {
        return uint72(uint256(1e27 * 0.1) / (86400 * 365)); // not SECONDS_PER_YEAR to avoid breaking tests
    }
}

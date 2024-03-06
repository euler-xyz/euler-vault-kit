// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../BaseIRM.sol";

contract IRMLinear is BaseIRM {
    uint256 internal constant MAX_IR = uint256(1e27 * 0.1) / SECONDS_PER_YEAR;

    function computeInterestRateImpl(address, address, uint32 utilisation) internal pure override returns (uint256) {
        return uint256(MAX_IR * utilisation / type(uint32).max);
    }
}

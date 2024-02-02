// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IIRM.sol";

abstract contract BaseIRM is IIRM {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar

    uint72 constant MAX_ALLOWED_INTEREST_RATE = uint72(uint256(5 * 1e27) / SECONDS_PER_YEAR); // 500% APR

    function computeInterestRateImpl(address, address, uint32) internal virtual returns (uint72);

    function computeInterestRate(address market, address asset, uint32 utilisation) external returns (uint256) {
        uint72 rate = computeInterestRateImpl(market, asset, utilisation);

        if (rate > MAX_ALLOWED_INTEREST_RATE) rate = MAX_ALLOWED_INTEREST_RATE;

        return rate;
    }

    function reset(address market, bytes calldata resetParams) external virtual {}
}

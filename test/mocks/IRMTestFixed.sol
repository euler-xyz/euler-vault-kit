// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../src/InterestRateModels/IIRM.sol";

contract IRMTestFixed is IIRM {
    constructor() {}

    function computeInterestRate(address, uint256, uint256) public pure returns (uint256) {
        return uint(1e27 * 0.1) / (86400 * 365); // not SECONDS_PER_YEAR to avoid breaking tests
    }

    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external pure returns (uint256) {
        return computeInterestRate(vault, cash, borrows);
    }
}

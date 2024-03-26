// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../InterestRateModels/IIRM.sol";

contract IRMZero is IIRM {
    function computeInterestRate(address, uint256, uint256) public pure returns (uint256) {
        return 0;
    }

    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external pure returns (uint256) {
        return computeInterestRate(vault, cash, borrows);
    }
}



// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../InterestRateModels/IIRM.sol";
import "../../EVault/shared/Constants.sol";


contract IRMLinear is IIRM {
    uint internal constant MAX_IR = uint(1e27 * 0.1) / SECONDS_PER_YEAR;

    function computeInterestRate(address, uint256 cash, uint256 borrows) public pure returns (uint256) {
        uint256 totalAssets = cash + borrows;

        uint32 utilisation = totalAssets == 0
           ? 0 // empty pool arbitrarily given utilisation of 0
           : uint32(borrows * type(uint32).max / totalAssets);

        return MAX_IR * utilisation / type(uint32).max;
    }

    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external pure returns (uint256) {
        return computeInterestRate(vault, cash, borrows);
    }
}

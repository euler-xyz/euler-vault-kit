// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IIRM {
    error E_IRMUpdateUnauthorized();

    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256);
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IIRM {
    function computeInterestRate(address market, address asset, uint32 utilisation) external returns (uint256);
    function reset(address market, bytes calldata resetParams) external;
}

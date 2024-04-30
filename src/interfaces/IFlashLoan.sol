// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

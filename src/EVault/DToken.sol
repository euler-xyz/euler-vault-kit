// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Errors} from "./shared/Errors.sol";
import {Events} from "./shared/Events.sol";
import {IERC20, IEVault} from "./IEVault.sol";

/// @title DToken
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Contract implements read only ERC20 interface, and `Transfer` events, for EVault's debt
contract DToken is IERC20, Errors, Events {
    address public immutable eVault;

    constructor() {
        eVault = msg.sender;
    }

    // ERC20 interface

    function name() external view returns (string memory) {
        return string.concat("Debt token of ", IEVault(eVault).name());
    }

    function symbol() external view returns (string memory) {
        return string.concat(IEVault(eVault).symbol(), "-DEBT");
    }

    function decimals() external view returns (uint8) {
        return IEVault(eVault).decimals();
    }

    function totalSupply() external view returns (uint256) {
        return IEVault(eVault).totalBorrows();
    }

    function balanceOf(address owner) external view returns (uint256) {
        return IEVault(eVault).debtOf(owner);
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        revert E_NotSupported();
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert E_NotSupported();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert E_NotSupported();
    }

    // Events

    function emitTransfer(address from, address to, uint256 value) external {
        if (msg.sender != eVault) revert E_Unauthorized();

        emit Transfer(from, to, value);
    }

    // Helpers

    function asset() external view returns (address) {
        return IEVault(eVault).asset();
    }
}

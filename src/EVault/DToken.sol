// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { Errors } from "./shared/Errors.sol";
import { Events } from "./shared/Events.sol";
import { IERC20, IEVault } from "./IEVault.sol";

// TODO use global interface
contract DToken is IERC20, Errors, Events {
    address immutable public eVault;

    constructor() {
        eVault = msg.sender;
    }

    // ERC20 interface

    function name() external view returns (string memory) {
        return string.concat("Debt token of ", IEVault(eVault).name());
    }

    function symbol() external view returns (string memory) {
        return string.concat("d", IEVault(eVault).symbol());
    }

    function decimals() external view returns (uint8) {
        return IEVault(eVault).decimals();
    }

    function totalSupply() external view returns (uint) {
        return IEVault(eVault).totalBorrows();
    }

    function balanceOf(address owner) external view returns (uint) {
        return IEVault(eVault).debtOf(owner);
    }

    function allowance(address, address) external pure returns (uint) {
        return 0;
    }

    function approve(address, uint) external pure returns (bool) {
        revert E_NotSupported();
    }

    function transfer(address, uint) external pure returns (bool) {
        revert E_NotSupported();
    }

    function transferFrom(address, address, uint) external pure returns (bool) {
        revert E_NotSupported();
    }

    //TODO
    function transferFromMax(address, address) external pure returns (bool) {
        revert E_NotSupported();
    }

    // Events

    function emitTransfer(address from, address to, uint value) external {
        if (msg.sender != eVault) revert E_Unauthorized();

        emit Transfer(from, to, value);
    }

    // Helpers

    function asset() external view returns (address) {
        return IEVault(eVault).asset();
    }
}
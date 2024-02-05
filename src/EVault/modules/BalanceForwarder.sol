// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBalanceForwarder} from "../IEVault.sol";
import {IBalanceTracker} from "../../IBalanceTracker.sol";
import {Base} from "../shared/Base.sol";
import {UserStorageLib} from "../shared/types/UserStorage.sol";

abstract contract BalanceForwarderModule is IBalanceForwarder, Base {
    using UserStorageLib for UserStorage;

    /// @inheritdoc IBalanceForwarder
    function balanceTrackerAddress() external view virtual reentrantOK returns (address) {
        return address(balanceTracker);
    }

    /// @inheritdoc IBalanceForwarder
    function balanceForwarderEnabled(address account) external view virtual reentrantOK returns (bool) {
        return marketStorage.users[account].getBalanceForwarderEnabled();
    }

    /// @inheritdoc IBalanceForwarder
    function enableBalanceForwarder() external virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address msgSender = EVCAuthenticate();
        bool wasBalanceForwarderEnabled = marketStorage.users[msgSender].getBalanceForwarderEnabled();

        marketStorage.users[msgSender].setBalanceForwarder(true);
        balanceTracker.balanceTrackerHook(msgSender, marketStorage.users[msgSender].getBalance().toUint(), false);

        if (!wasBalanceForwarderEnabled) emit BalanceForwarderStatus(msgSender, true);
    }

    /// @inheritdoc IBalanceForwarder
    function disableBalanceForwarder() external virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address msgSender = EVCAuthenticate();
        bool wasBalanceForwarderEnabled = marketStorage.users[msgSender].getBalanceForwarderEnabled();

        marketStorage.users[msgSender].setBalanceForwarder(false);
        balanceTracker.balanceTrackerHook(msgSender, 0, false);

        if (wasBalanceForwarderEnabled) emit BalanceForwarderStatus(msgSender, false);
    }
}

contract BalanceForwarder is BalanceForwarderModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}

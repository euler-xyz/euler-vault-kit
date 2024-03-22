// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBalanceForwarder} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

abstract contract BalanceForwarderModule is IBalanceForwarder, Base {
    /// @inheritdoc IBalanceForwarder
    function balanceTrackerAddress() public view virtual reentrantOK returns (address) {
        return address(balanceTracker);
    }

    /// @inheritdoc IBalanceForwarder
    function balanceForwarderEnabled(address account) public view virtual reentrantOK returns (bool) {
        return marketStorage().users[account].getBalanceForwarderEnabled();
    }

    /// @inheritdoc IBalanceForwarder
    function enableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        User storage user = marketStorage().users[account];
        bool wasBalanceForwarderEnabled = user.getBalanceForwarderEnabled();

        user.setBalanceForwarder(true);
        balanceTracker.balanceTrackerHook(account, user.getBalance().toUint(), false);

        if (!wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, true);
    }

    /// @inheritdoc IBalanceForwarder
    function disableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        bool wasBalanceForwarderEnabled = marketStorage.users[account].getBalanceForwarderEnabled();

        marketStorage.users[account].setBalanceForwarder(false);
        balanceTracker.balanceTrackerHook(account, 0, false);

        if (wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, false);
    }
}

contract BalanceForwarder is BalanceForwarderModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

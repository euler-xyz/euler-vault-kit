// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBalanceForwarder} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {User} from "../shared/types/User.sol";

abstract contract BalanceForwarderModule is IBalanceForwarder, Base {
    /// @inheritdoc IBalanceForwarder
    function balanceTrackerAddress() public view virtual reentrantOK returns (address) {
        return address(balanceTracker);
    }

    /// @inheritdoc IBalanceForwarder
    function balanceForwarderEnabled(address account) public view virtual reentrantOK returns (bool) {
        return vaultStorage().users[account].getBalanceForwarderEnabled();
    }

    /// @inheritdoc IBalanceForwarder
    function enableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        User storage user = vaultStorage().users[account];
        bool wasBalanceForwarderEnabled = user.getBalanceForwarderEnabled();

        user.setBalanceForwarder(true);
        balanceTracker.balanceTrackerHook(account, user.getBalance().toUint(), false);

        if (!wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, true);
    }

    /// @inheritdoc IBalanceForwarder
    function disableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        User storage user = vaultStorage().users[account];
        bool wasBalanceForwarderEnabled = user.getBalanceForwarderEnabled();

        user.setBalanceForwarder(false);
        balanceTracker.balanceTrackerHook(account, 0, false);

        if (wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, false);
    }
}

contract BalanceForwarder is BalanceForwarderModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

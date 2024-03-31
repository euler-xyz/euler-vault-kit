// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBalanceForwarder} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

/// @title BalanceForwarderModule
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An EVault module handling communication a with balance tracker contract.
abstract contract BalanceForwarderModule is IBalanceForwarder, Base {
    /// @inheritdoc IBalanceForwarder
    function balanceTrackerAddress() public view virtual reentrantOK returns (address) {
        return address(balanceTracker);
    }

    /// @inheritdoc IBalanceForwarder
    function balanceForwarderEnabled(address account) public view virtual reentrantOK returns (bool) {
        return vaultStorage.users[account].isBalanceForwarderEnabled();
    }

    /// @inheritdoc IBalanceForwarder
    function enableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        bool wasBalanceForwarderEnabled = vaultStorage.users[account].isBalanceForwarderEnabled();

        vaultStorage.users[account].setBalanceForwarder(true);
        balanceTracker.balanceTrackerHook(account, vaultStorage.users[account].getBalance().toUint(), false);

        if (!wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, true);
    }

    /// @inheritdoc IBalanceForwarder
    function disableBalanceForwarder() public virtual reentrantOK {
        if (address(balanceTracker) == address(0)) revert E_BalanceForwarderUnsupported();

        address account = EVCAuthenticate();
        bool wasBalanceForwarderEnabled = vaultStorage.users[account].isBalanceForwarderEnabled();

        vaultStorage.users[account].setBalanceForwarder(false);
        balanceTracker.balanceTrackerHook(account, 0, false);

        if (wasBalanceForwarderEnabled) emit BalanceForwarderStatus(account, false);
    }
}

/// @dev Deployable module contract
contract BalanceForwarder is BalanceForwarderModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

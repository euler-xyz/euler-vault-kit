// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {IBalanceTracker} from "../../interfaces/IBalanceTracker.sol";

import "./types/Types.sol";

abstract contract BalanceUtils is Base {
    using TypesLib for uint256;

    // Balances

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal {
        if (account == address(0)) revert E_BadSharesReceiver();

        VaultData storage _vaultStorage = vaultStorage();
        (Shares origBalance, bool balanceForwarderEnabled) =
            _vaultStorage.users[account].getBalanceAndBalanceForwarder();
        Shares newBalance = origBalance + amount;

        _vaultStorage.users[account].setBalance(newBalance);
        _vaultStorage.totalShares = vaultCache.totalShares = vaultCache.totalShares + amount;

        if (balanceForwarderEnabled) {
            tryBalanceTrackerHook(account, newBalance.toUint(), false);
        }

        emit Transfer(address(0), account, amount.toUint());
        emit Deposit(sender, account, assets.toUint(), amount.toUint());
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal {
        VaultData storage _vaultStorage = vaultStorage();

        (Shares origBalance, bool balanceForwarderEnabled) =
            _vaultStorage.users[account].getBalanceAndBalanceForwarder();
        if (origBalance < amount) revert E_InsufficientBalance();

        Shares newBalance;
        unchecked {
            newBalance = origBalance - amount;
        }

        _vaultStorage.users[account].setBalance(newBalance);
        _vaultStorage.totalShares = vaultCache.totalShares = vaultCache.totalShares - amount;

        if (balanceForwarderEnabled) {
            tryBalanceTrackerHook(account, newBalance.toUint(), isControlCollateralInProgress());
        }

        emit Transfer(account, address(0), amount.toUint());
        emit Withdraw(sender, receiver, account, assets.toUint(), amount.toUint());
    }

    function transferBalance(address from, address to, Shares amount) internal {
        VaultData storage _vaultStorage = vaultStorage();

        if (!amount.isZero()) {
            (Shares origFromBalance, bool fromBalanceForwarderEnabled) =
                _vaultStorage.users[from].getBalanceAndBalanceForwarder();

            (Shares origToBalance, bool toBalanceForwarderEnabled) =
                _vaultStorage.users[to].getBalanceAndBalanceForwarder();

            if (origFromBalance < amount) revert E_InsufficientBalance();

            Shares newFromBalance;
            unchecked {
                newFromBalance = origFromBalance - amount;
            }
            Shares newToBalance = origToBalance + amount;

            _vaultStorage.users[from].setBalance(newFromBalance);
            _vaultStorage.users[to].setBalance(newToBalance);

            if (fromBalanceForwarderEnabled) {
                tryBalanceTrackerHook(from, newFromBalance.toUint(), isControlCollateralInProgress());
            }

            if (toBalanceForwarderEnabled) {
                tryBalanceTrackerHook(to, newToBalance.toUint(), false);
            }
        }

        emit Transfer(from, to, amount.toUint());
    }

    // Allowance

    function setAllowance(address owner, address spender, uint256 amount) internal {
        if (spender == owner) revert E_SelfApproval();

        vaultStorage().users[owner].eTokenAllowance[spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function decreaseAllowance(address owner, address spender, Shares amount) internal {
        if (amount.isZero()) return;
        VaultData storage _vaultStorage = vaultStorage();

        uint256 allowance = _vaultStorage.users[owner].eTokenAllowance[spender];
        if (owner != spender && allowance != type(uint256).max) {
            if (allowance < amount.toUint()) revert E_InsufficientAllowance();
            unchecked {
                allowance -= amount.toUint();
            }
            _vaultStorage.users[owner].eTokenAllowance[spender] = allowance;
            emit Approval(owner, spender, allowance);
        }
    }

    function tryBalanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward)
        private
        returns (bool success)
    {
        (success,) = address(balanceTracker).call(
            abi.encodeCall(IBalanceTracker.balanceTrackerHook, (account, newAccountBalance, forfeitRecentReward))
        );
    }
}

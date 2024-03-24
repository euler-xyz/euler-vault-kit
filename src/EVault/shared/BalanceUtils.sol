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

        VaultData storage vs = vaultStorage();
        (Shares origBalance, bool balanceForwarderEnabled) = vs.users[account].getBalanceAndBalanceForwarder();
        Shares newBalance = origBalance + amount;

        vs.users[account].setBalance(newBalance);
        vs.totalShares = vaultCache.totalShares = vaultCache.totalShares + amount;

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
        VaultData storage vs = vaultStorage();

        (Shares origBalance, bool balanceForwarderEnabled) = vs.users[account].getBalanceAndBalanceForwarder();
        if (origBalance < amount) revert E_InsufficientBalance();

        Shares newBalance;
        unchecked {
            newBalance = origBalance - amount;
        }

        vs.users[account].setBalance(newBalance);
        vs.totalShares = vaultCache.totalShares = vaultCache.totalShares - amount;

        if (balanceForwarderEnabled) {
            tryBalanceTrackerHook(account, newBalance.toUint(), isControlCollateralInProgress());
        }

        emit Transfer(account, address(0), amount.toUint());
        emit Withdraw(sender, receiver, account, assets.toUint(), amount.toUint());
    }

    function transferBalance(address from, address to, Shares amount) internal {
        VaultData storage vs = vaultStorage();

        if (!amount.isZero()) {
            (Shares origFromBalance, bool fromBalanceForwarderEnabled) = vs.users[from].getBalanceAndBalanceForwarder();

            (Shares origToBalance, bool toBalanceForwarderEnabled) = vs.users[to].getBalanceAndBalanceForwarder();

            if (origFromBalance < amount) revert E_InsufficientBalance();

            Shares newFromBalance;
            unchecked {
                newFromBalance = origFromBalance - amount;
            }
            Shares newToBalance = origToBalance + amount;

            vs.users[from].setBalance(newFromBalance);
            vs.users[to].setBalance(newToBalance);

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
        VaultData storage vs = vaultStorage();

        uint256 allowance = vs.users[owner].eTokenAllowance[spender];
        if (owner != spender && allowance != type(uint256).max) {
            if (allowance < amount.toUint()) revert E_InsufficientAllowance();
            unchecked {
                allowance -= amount.toUint();
            }
            vs.users[owner].eTokenAllowance[spender] = allowance;
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

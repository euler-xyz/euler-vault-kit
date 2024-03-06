// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {DToken} from "../DToken.sol";
import {Base} from "./Base.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "./types/Types.sol";

abstract contract BalanceUtils is Base {
    using TypesLib for uint256;

    // Balances

    function increaseBalance(
        MarketCache memory marketCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal {
        // alcueca: Unlike in `transferBalance`, here we allow increasing balance by zero
        (Shares origBalance, bool balanceForwarderEnabled) =
            marketStorage.users[account].getBalanceAndBalanceForwarder();
        Shares newBalance = origBalance + amount;

        if (balanceForwarderEnabled) {
            balanceTracker.balanceTrackerHook(account, newBalance.toUint(), false);
        }

        marketStorage.users[account].setBalance(newBalance);
        marketStorage.totalShares = marketCache.totalShares = marketCache.totalShares + amount;

        emit Transfer(address(0), account, amount.toUint());
        emit Deposit(sender, account, assets.toUint(), amount.toUint());
    }

    function decreaseBalance(
        MarketCache memory marketCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal {
        // alcueca: Unlike in `transferBalance`, here we allow decreasing balance by zero
        (Shares origBalance, bool balanceForwarderEnabled) =
            marketStorage.users[account].getBalanceAndBalanceForwarder();
        if (origBalance < amount) revert E_InsufficientBalance();

        Shares newBalance;
        unchecked {
            newBalance = origBalance - amount;
        }

        if (balanceForwarderEnabled) {
            balanceTracker.balanceTrackerHook(account, newBalance.toUint(), isControlCollateralInProgress()); // alcueca: We forfeit rewards when doing a liquidation
        }

        marketStorage.users[account].setBalance(newBalance);
        marketStorage.totalShares = marketCache.totalShares = marketCache.totalShares - amount;

        emit Transfer(account, address(0), amount.toUint());
        emit Withdraw(sender, receiver, account, assets.toUint(), amount.toUint());
    }

    function transferBalance(address from, address to, Shares amount) internal {
        if (!amount.isZero()) {
            (Shares origFromBalance, bool fromBalanceForwarderEnabled) =
                marketStorage.users[from].getBalanceAndBalanceForwarder();
            (Shares origToBalance, bool toBalanceForwarderEnabled) = marketStorage.users[to].getBalanceAndBalanceForwarder();
            if (origFromBalance < amount) revert E_InsufficientBalance();

            Shares newFromBalance;
            unchecked {
                newFromBalance = origFromBalance - amount;
            }
            Shares newToBalance = origToBalance + amount;

            if (fromBalanceForwarderEnabled) {
                balanceTracker.balanceTrackerHook(from, newFromBalance.toUint(), isControlCollateralInProgress()); // alcueca: We forfeit rewards when doing a liquidation
            }
            if (toBalanceForwarderEnabled) {
                balanceTracker.balanceTrackerHook(to, newToBalance.toUint(), false);
            }

            marketStorage.users[from].setBalance(newFromBalance);
            marketStorage.users[to].setBalance(newToBalance);
        }

        emit Transfer(from, to, amount.toUint()); // alcueca: I think that sending events for no-ops is bad practice
    }

    // Allowance

    function setAllowance(address owner, address spender, uint256 amount) internal {
        if (spender == owner) revert E_SelfApproval();

        marketStorage.eVaultAllowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function decreaseAllowance(address owner, address spender, Shares amount) internal {
        if (amount.isZero()) return; // alcueca: inconsistent with `increaseBalance` and `transferBalance`.
        uint256 allowance = marketStorage.eVaultAllowance[owner][spender];
        if (owner != spender && allowance != type(uint256).max) {
            if (allowance < amount.toUint()) revert E_InsufficientAllowance();
            unchecked {
                allowance -= amount.toUint();
            }
            marketStorage.eVaultAllowance[owner][spender] = allowance;
            emit Approval(owner, spender, allowance);
        }
    }
}

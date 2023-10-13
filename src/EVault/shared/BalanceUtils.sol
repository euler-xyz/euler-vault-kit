// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Events} from "./Events.sol";
import {Errors} from "./Errors.sol";

import "./types/Types.sol";

abstract contract BalanceUtils is Storage, Events, Errors {
    using TypesLib for uint;

   // Balances

    function increaseBalance(MarketCache memory marketCache, address account, Shares amount) internal {
        marketStorage.users[account].balance = marketStorage.users[account].balance + amount;
        marketStorage.totalBalances = marketCache.totalBalances = marketCache.totalBalances + amount;

        emit IncreaseBalance(address(this), account, amount.toUint());
        emit Transfer(address(0), account, amount.toUint());
    }

    function decreaseBalance(MarketCache memory marketCache, address account, Shares amount) internal {
        Shares origBalance = marketStorage.users[account].balance;
        if (origBalance < amount) revert E_InsufficientBalance();
        marketStorage.users[account].balance = origBalance - amount;

        marketStorage.totalBalances = marketCache.totalBalances = marketCache.totalBalances - amount;

        emit DecreaseBalance(address(this), account, amount.toUint());
        emit Transfer(account, address(0), amount.toUint());
    }

    function transferBalance(address from, address to, Shares amount) internal {
        Shares origFromBalance = marketStorage.users[from].balance;
        if (origFromBalance < amount) revert E_InsufficientBalance();
        Shares newFromBalance;
        unchecked { newFromBalance = origFromBalance - amount; }

        marketStorage.users[from].balance = newFromBalance;
        marketStorage.users[to].balance = marketStorage.users[to].balance + amount;

        emit DecreaseBalance(address(this), from, amount.toUint());
        emit IncreaseBalance(address(this), to, amount.toUint());
        emit Transfer(from, to, amount.toUint());
    }

    // Allowance

    function decreaseAllowance(address from, address to, Shares amount) internal {
        uint allowanceCache = marketStorage.eVaultAllowance[from][to];
        if (from != to && allowanceCache != type(uint).max) {
            if (allowanceCache < amount.toUint()) revert E_InsufficientAllowance();
            unchecked { allowanceCache -= amount.toUint(); }
            marketStorage.eVaultAllowance[from][to] = allowanceCache;
            emit Approval(from, to, allowanceCache);
        }
    }

    function withdrawAmounts(MarketCache memory marketCache, address account, uint amount) internal view returns (Assets assets, Shares shares) {
        if (amount == type(uint).max) {
            shares = marketStorage.users[account].balance;
            assets = shares.toAssetsDown(marketCache);
        } else {
            assets = amount.toAssets();
            shares = assets.toSharesUp(marketCache);
        }

        return (assets, shares);
    }
}

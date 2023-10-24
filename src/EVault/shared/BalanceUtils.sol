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

        emit Transfer(address(0), account, amount.toUint());
    }
}

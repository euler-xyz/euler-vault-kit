// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {Storage} from "./Storage.sol";
import {Errors} from "./Errors.sol";

import "./types/Types.sol";

contract AssetTransfers is Storage, Errors {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal {
        marketCache.asset.safeTransferFrom(from, address(this), amount.toUint());
        marketStorage.cash = marketCache.cash = marketCache.cash + amount;
    }

    function pushTokens(MarketCache memory marketCache, address to, Assets amount) internal {
        marketStorage.cash = marketCache.cash = marketCache.cash - amount;
        marketCache.asset.safeTransfer(to, amount.toUint());
    }
}

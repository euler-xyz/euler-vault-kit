// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {Errors} from "./Errors.sol";

import "./types/Types.sol";

contract AssetTransfers is Errors {
    using TypesLib for uint;
    using SafeERC20Lib for IERC20;

    function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal returns (Assets amountTransferred) {
        Assets poolSizeBefore = marketCache.poolSize;

        marketCache.asset.safeTransferFrom(from, address(this), amount.toUint());
        Assets poolSizeAfter = marketCache.poolSize = marketCache.asset.callBalanceOf(address(this)).toAssets();

        if (poolSizeAfter < poolSizeBefore) revert E_NegativeTransferAmount();
        unchecked { amountTransferred = poolSizeAfter - poolSizeBefore; }
    }
}

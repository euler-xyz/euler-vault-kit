// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./types/Types.sol";
import "./lib/Utils.sol";
import "./Errors.sol";

contract AssetTransfers is Errors {
    using TypesLib for uint;

    function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal returns (Assets amountTransferred) {
        Assets poolSizeBefore = marketCache.poolSize;

        Utils.safeTransferFrom(marketCache.asset, from, address(this), amount.toUint());
        Assets poolSizeAfter = marketCache.poolSize = Utils.callBalanceOf(marketCache.asset, address(this)).toAssets();

        if (poolSizeAfter < poolSizeBefore) revert E_NegativeTransferAmount();
        unchecked { amountTransferred = poolSizeAfter - poolSizeBefore; }
    }

    // function pushTokens(MarketCache memory marketCache, address to, Assets amount) internal returns (Assets amountTransferred) {
    //     Assets poolSizeBefore = marketCache.poolSize;

    //     Utils.safeTransfer(marketCache.asset, to, amount.toUint());
    //     Assets poolSizeAfter = marketCache.poolSize = Utils.callBalanceOf(marketCache.asset, address(this)).toAssets();

    //     if (poolSizeBefore < poolSizeAfter) revert E_NegativeTransferAmount();
    //     unchecked { amountTransferred = poolSizeBefore - poolSizeAfter; }
    // }
}
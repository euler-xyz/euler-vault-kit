// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {Base} from "./Base.sol";

import "./types/Types.sol";

abstract contract AssetTransfers is Base {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    function pullAssets(MarketCache memory marketCache, address from, Assets amount) internal {
        marketCache.asset.safeTransferFrom(from, address(this), amount.toUint(), permit2);
        marketStorage.cash = marketCache.cash = marketCache.cash + amount;
    }

    function pushAssets(MarketCache memory marketCache, address to, Assets amount) internal {
        if (
            to == address(0)
            // If the op is enabled, do not send assets to an address that is recognized by EVC
            // as a sub-account of some other address. If the asset itself is not compatible with EVC
            // and sub-accounts, the funds would be lost.
            || (marketCache.disabledOps.isNotSet(OP_VALIDATE_ASSET_RECEIVER) && isKnownSubaccount(to))
        ) {
            revert E_BadAssetReceiver();
        }

        marketStorage.cash = marketCache.cash = marketCache.cash - amount;
        marketCache.asset.safeTransfer(to, amount.toUint());
    }
}

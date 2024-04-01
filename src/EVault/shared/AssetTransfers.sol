// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SafeERC20Lib} from "./lib/SafeERC20Lib.sol";
import {Base} from "./Base.sol";

import "./types/Types.sol";

/// @title AssetTransfers
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Transfer assets into and out of the vault
abstract contract AssetTransfers is Base {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    function pullAssets(VaultCache memory vaultCache, address from, Assets amount) internal {
        vaultCache.asset.safeTransferFrom(from, address(this), amount.toUint(), permit2);
        vaultStorage.cash = vaultCache.cash = vaultCache.cash + amount;
    }

    function pushAssets(VaultCache memory vaultCache, address to, Assets amount) internal {
        if (
            to == address(0)
            // If the underlying asset is not EVC-compatible, do not transfer assets to any
            // address that the EVC knows to be a sub-account. Non-EVC-compatible tokens do
            // not know about sub-accounts, so the funds would be lost.
            || (vaultCache.configFlags.isNotSet(CFG_EVC_COMPATIBLE_ASSET) && isKnownSubaccount(to))
        ) {
            revert E_BadAssetReceiver();
        }

        vaultStorage.cash = vaultCache.cash = vaultCache.cash - amount;
        vaultCache.asset.safeTransfer(to, amount.toUint());
    }
}

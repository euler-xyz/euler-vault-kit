// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC4626, IEVault} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract ERC4626Module is IERC4626, Base, AssetTransfers, BalanceUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IERC4626
    function asset() external view virtual reentrantOK returns (address) {
        (IERC20 asset_,) = ProxyUtils.metadata();
        return address(asset_);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.poolSize.toUint() + marketCache.totalBorrows.toUintAssetsDown();
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_DEPOSIT, ACCOUNT_CHECK_NONE);

        if (receiver == address(0)) receiver = account;

        Assets assets =
            amount == type(uint256).max ? marketCache.asset.callBalanceOf(account).toAssets() : amount.toAssets();

        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        finalizeDeposit(marketCache, assets, shares, account, receiver);

        return shares.toUint();
    }

    function finalizeDeposit(
        MarketCache memory marketCache,
        Assets assets,
        Shares shares,
        address sender,
        address receiver
    ) private {
        pullTokens(marketCache, sender, assets);

        increaseBalance(marketCache, receiver, sender, shares, assets);
    }
}

contract ERC4626 is ERC4626Module {
    constructor(address evc) Base(evc) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC4626} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract ERC4626Module is IERC4626, Base, AssetTransfers, BalanceUtils {
    using TypesLib for uint;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address) {
        (IERC20 asset_,) = ProxyUtils.metadata();
        return address(asset_);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketNonReentrant();

        // TODO double check this: in V1 totalSupplyUnderlying was converted from totalSupply.
        // Now without initial shares balance, tokens transferred directly to vault would not be shown in conversion from 0.
        // See "market activation with pre-existing pool balance" test
        // The first depositor gets all the assets, but must deposit more than existing balance
        // return sharesToAssets(marketCache, marketCache.totalBalances);
        return marketCache.poolSize.toUint() + marketCache.totalBorrows.toUintAssetsDown();
    }

    /// @inheritdoc IERC4626
    function deposit(uint amount, address receiver) external virtual routedThroughCVC nonReentrant returns (uint) {
        // INIT
        (MarketCache memory marketCache, address account) = initMarketAndAccount(PAUSETYPE__DEPOSIT);

        if (receiver == address(0)) receiver = account;

        emit RequestDeposit(account, receiver, amount);

        Assets assets = amount == type(uint).max
            ? marketCache.asset.callBalanceOf(account).toAssets()
            : amount.toAssets();

        if (assets.isZero()) return 0;

        Assets assetsTransferred = pullTokens(marketCache, account, assets);
        // pullTokens() updates poolSize in the cache, but we need shares amount converted before the update,
        // excluding the assets transferred
        Shares shares = assetsTransferred.toSharesDownPremoney(marketCache);

        if (shares.isZero()) revert E_ZeroShares();

        increaseBalance(marketCache, receiver, shares);

        emit Deposit(account, receiver, assetsTransferred.toUint(), shares.toUint());

        // FINALIZE AND RETURN
        checkMarketAndAccountStatus(marketCache, address(0));
        return shares.toUint();
    }
}

contract ERC4626 is ERC4626Module {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}

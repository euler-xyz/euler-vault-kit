// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC4626} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {Utils} from "../shared/lib/Utils.sol";

import "../shared/types/Types.sol";

abstract contract ERC4626Module is IERC4626, Base, AssetTransfers, BalanceUtils {
    using TypesLib for uint;

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address) {
        (address asset_,) = proxyMetadata();
        return asset_;
    }

    // @inheritdoc IERC4626
    function deposit(uint assets, address receiver) external virtual nonReentrantWithChecks returns (uint shares) {
        shares = _deposit(CVCAuthenticate(), loadAndUpdateMarket(), assets, receiver);
    }
    function _deposit(address account, MarketCache memory marketCache, uint amount, address receiver) private
        lock(address(0), marketCache, PAUSETYPE__DEPOSIT)
        returns (uint)
    {
        // TODO defaultTo on address
        if (receiver == address(0)) receiver = account;

        emit RequestDeposit(account, receiver, amount);

        Assets assets = amount == type(uint).max
            ? Utils.callBalanceOf(marketCache.asset, account).toAssets()
            : amount.toAssets();

        Assets assetsTransferred = pullTokens(marketCache, account, assets);

        // pullTokens() updates poolSize in the cache, but we need the poolSize before the deposit to determine
        // the internal amount so temporarily reduce it by the amountTransferred (which is size checked within
        // pullTokens()). We can't compute this value before the pull because we don't know how much we'll
        // actually receive (the token might be deflationary).
        Shares shares;
        unchecked {
            marketCache.poolSize = marketCache.poolSize - assetsTransferred;
            shares = assetsTransferred.toSharesDown(marketCache);
            marketCache.poolSize = marketCache.poolSize + assetsTransferred;
        }

        if (shares.isZero()) revert E_ZeroShares();

        increaseBalance(marketCache, receiver, shares);

        emit Deposit(account, receiver, assetsTransferred.toUint(), shares.toUint());

        return shares.toUint();
    }
}

contract ERC4626 is ERC4626Module {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}

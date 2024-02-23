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
        (IERC20 asset_) = ProxyUtils.metadata();
        return address(asset_);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual nonReentrantView returns (uint256) {
        return totalAssetsInternal();
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return shares.toShares().toAssetsDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return assets.toAssets().toSharesDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address account) public view virtual nonReentrantView returns (uint256) {
        return maxDepositInternal(account);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view virtual nonReentrantView returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function maxMint(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return maxDepositInternal(account).toAssets().toSharesDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return shares.toShares().toAssetsUp(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) external view virtual nonReentrantView returns (uint256) {
        if (isOperationDisabled(OP_WITHDRAW)) return 0;

        MarketCache memory marketCache = loadMarket();
        return maxRedeemInternal(owner).toAssetsDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return assets.toAssets().toSharesUp(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view virtual nonReentrantView returns (uint256) {
        if (isOperationDisabled(OP_REDEEM)) return 0;

        return maxRedeemInternal(owner).toUint();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view virtual nonReentrantView returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_DEPOSIT, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        Assets assets =
            amount == type(uint256).max ? marketCache.asset.callBalanceOf(account).toAssets() : amount.toAssets();
        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        finalizeDeposit(marketCache, assets, shares, account, receiver);

        return shares.toUint();
    }

    /// @inheritdoc IERC4626
    function mint(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_MINT, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        Shares shares = amount.toShares();
        if (shares.isZero()) return 0;

        Assets assets = shares.toAssetsUp(marketCache);

        finalizeDeposit(marketCache, assets, shares, account, receiver);

        return assets.toUint();
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 amount, address receiver, address owner)
        external
        virtual
        nonReentrant
        returns (uint256)
    {
        (MarketCache memory marketCache, address account) = initOperation(OP_WITHDRAW, owner);

        if (receiver == address(0)) receiver = getAccountOwner(owner);

        Assets assets = amount.toAssets();
        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesUp(marketCache);

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);

        return shares.toUint();
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 amount, address receiver, address owner) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_REDEEM, owner);

        if (receiver == address(0)) receiver = getAccountOwner(owner);

        Shares shares = amount == type(uint256).max ? marketStorage.users[owner].getBalance() : amount.toShares();
        if (shares.isZero()) return 0;

        Assets assets = shares.toAssetsDown(marketCache);

        if (assets.isZero()) revert E_ZeroAssets();

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);

        return assets.toUint();
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

    function finalizeWithdraw(
        MarketCache memory marketCache,
        Assets assets,
        Shares shares,
        address sender,
        address receiver,
        address owner
    ) private {
        if (marketCache.poolSize < assets) revert E_InsufficientPoolSize();

        decreaseAllowance(owner, sender, shares);
        decreaseBalance(marketCache, owner, sender, receiver, shares, assets);

        pushTokens(marketCache, receiver, assets);
    }

    function maxRedeemInternal(address owner) internal view returns (Shares) {
        Shares max = marketStorage.users[owner].getBalance();
        if (max.isZero()) return Shares.wrap(0);

        // When checks are deferred, all of the balance can be withdrawn, even if only temporarily
        if (!isAccountStatusCheckDeferred(owner)) {
            address controller = getController(owner);

            if (controller != address(0)) {
                try IEVault(controller).collateralUsed(address(this), owner) returns (uint256 locked) {
                    if (locked >= max.toUint()) return Shares.wrap(0);
                    max = max - locked.toShares();
                } catch {} // if controller doesn't implement the function, assume it will not block withdrawal
            }
        }

        MarketCache memory marketCache = loadMarket();

        Shares poolSize = marketCache.poolSize.toSharesDown(marketCache);
        max = max > poolSize ? poolSize : max;

        return max;
    }

    function totalAssetsInternal() private view returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return marketCache.poolSize.toUint() + marketCache.totalBorrows.toAssetsUp().toUint();
    }

    function maxDepositInternal(address) private view returns (uint256) {
        // TODO optimize read
        if (marketStorage.disabledOps.get(OP_DEPOSIT)) return 0;
        uint256 supplyCap = marketStorage.supplyCap.toUint();

        uint256 currentSupply = totalAssetsInternal();
        uint256 max = currentSupply < supplyCap ? supplyCap - currentSupply : 0;

        return max > MAX_SANE_AMOUNT ? MAX_SANE_AMOUNT : max;
    }

    function isOperationDisabled(uint32 operations) private view returns (bool) {
        // TODO optimize read
        return marketStorage.disabledOps.get(operations);
    }
}

contract ERC4626 is ERC4626Module {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IVault, IEVault, IERC4626} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract VaultModule is IVault, Base, AssetTransfers, BalanceUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IERC4626
    function asset() external view virtual reentrantOK returns (address) {
        (IERC20 _asset,,) = ProxyUtils.metadata();
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return totalAssetsInternal(marketCache);
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
        MarketCache memory marketCache = loadMarket();
        if (marketCache.disabledOps.get(OP_DEPOSIT)) return 0;

        return maxDepositInternal(marketCache, account);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view virtual nonReentrantView returns (uint256) {
        return convertToShares(assets);
    }

    /// @inheritdoc IERC4626
    function maxMint(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        if (marketCache.disabledOps.get(OP_MINT)) return 0;
        return maxDepositInternal(marketCache, account).toAssets().toSharesDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return shares.toShares().toAssetsUp(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        if (marketCache.disabledOps.get(OP_WITHDRAW)) return 0;

        return maxRedeemInternal(owner).toAssetsDown(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        return assets.toAssets().toSharesUp(marketCache).toUint();
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        if (marketCache.disabledOps.get(OP_REDEEM)) return 0;

        return maxRedeemInternal(owner).toUint();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view virtual nonReentrantView returns (uint256) {
        return convertToAssets(shares);
    }

    /// @inheritdoc IVault
    function feesBalance() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().feesBalance.toUint();
    }

    /// @inheritdoc IVault
    function feesBalanceAssets() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.feesBalance.toAssetsDown(marketCache).toUint();
    }


    /// @inheritdoc IERC4626
    function deposit(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_DEPOSIT, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        Assets assets =
            amount == type(uint256).max ? marketCache.asset.balanceOf(account).toAssets() : amount.toAssets();
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

    /// @inheritdoc IVault
    function skimAssets() external virtual nonReentrant {
        // TODO make it callable directly only, just to be double safe?
        (address admin, address receiver) = protocolConfig.skimConfig(address(this));
        if (msg.sender != admin) revert E_Unauthorized();
        if (receiver == address(0) || receiver == address(this)) revert E_BadAddress();

        (IERC20 _asset,,) = ProxyUtils.metadata();

        uint256 balance = _asset.balanceOf(address(this));
        uint256 poolSize = marketStorage.poolSize.toUint();
        if (balance > poolSize) {
            uint256 amount = balance - poolSize;
            _asset.transfer(receiver, amount);
            emit SkimAssets(admin, receiver, amount);
        }
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
                (bool success, bytes memory data) = controller.staticcall(abi.encodeCall(IBorrowing.collateralUsed, (address(this), owner)));
                // if controller doesn't implement the function, assume it will not block withdrawal
                if (success) {
                    uint256 used = abi.decode(data, (uint256));
                    if (used >= max.toUint()) return Shares.wrap(0);
                    max = max - used.toShares();
                }
            }
        }

        MarketCache memory marketCache = loadMarket();

        Shares poolSize = marketCache.poolSize.toSharesDown(marketCache);
        max = max > poolSize ? poolSize : max;

        return max;
    }

    function maxDepositInternal(MarketCache memory marketCache, address) private pure returns (uint256) {
        uint256 supply = totalAssetsInternal(marketCache);
        if(supply >= marketCache.supplyCap) return 0;

        uint256 remainingSupply = marketCache.supplyCap - supply;
        uint256 remainingPoolSize = MAX_SANE_AMOUNT - marketCache.poolSize.toUint();

        return remainingPoolSize < remainingSupply ? remainingPoolSize : remainingSupply;
    }
}

contract Vault is VaultModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

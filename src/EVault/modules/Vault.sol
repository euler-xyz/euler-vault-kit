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
    function accumulatedFees() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().accumulatedFees.toUint();
    }

    /// @inheritdoc IVault
    function accumulatedFeesAssets() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.accumulatedFees.toAssetsDown(marketCache).toUint();
    }

    /// @inheritdoc IVault
    function creator() external view virtual reentrantOK returns (address) {
        return marketStorage.creator;
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
    function skim(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_SKIM, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        Assets balance = marketCache.asset.balanceOf(address(this)).toAssets();
        Assets available = balance <= marketCache.cash
            ? Assets.wrap(0)
            : balance - marketCache.cash;

        Assets assets;
        if (amount == type(uint256).max) {
            assets = available;
        } else {
            assets = amount.toAssets();
            if (assets > available) revert E_InsufficientAssets();
        }
        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        increaseBalance(marketCache, receiver, account, shares, assets);

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

    function finalizeWithdraw(
        MarketCache memory marketCache,
        Assets assets,
        Shares shares,
        address sender,
        address receiver,
        address owner
    ) private {
        if (marketCache.cash < assets) revert E_InsufficientCash();

        decreaseAllowance(owner, sender, shares);
        decreaseBalance(marketCache, owner, sender, receiver, shares, assets);

        pushTokens(marketCache, receiver, assets);
    }

    function maxRedeemInternal(address owner) internal view returns (Shares) {
        Shares max = marketStorage.users[owner].getBalance();
        if (max.isZero()) return max;

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

        Shares cash = marketCache.cash.toSharesDown(marketCache);
        max = max > cash ? cash : max;

        return max;
    }

    function maxDepositInternal(MarketCache memory marketCache, address) private view returns (uint256) {
        uint remainingSupply;

        // In transient state with vault status checks deferred, supply caps will not be immediately enforced
        if (isVaultStatusCheckDeferred()) {
            remainingSupply = type(uint256).max;
        } else {
            uint256 supply = totalAssetsInternal(marketCache);
            if(supply >= marketCache.supplyCap) return 0;

            remainingSupply = marketCache.supplyCap - supply;
        }

        uint256 remainingCash = MAX_SANE_AMOUNT - marketCache.cash.toUint();

        return remainingCash < remainingSupply ? remainingCash : remainingSupply;
    }
}

contract Vault is VaultModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

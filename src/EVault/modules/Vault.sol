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
    function maxDeposit(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        if (marketCache.disabledOps.get(OP_DEPOSIT)) return 0;

        return maxDepositInternal(marketCache, account);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view virtual nonReentrantView returns (uint256) {
        return convertToShares(assets); // Doesn't take into account the `assets == type(uint256).max` case
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
    function maxRedeem(address owner) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();
        if (marketCache.disabledOps.get(OP_REDEEM)) return 0;

        return maxRedeemInternal(owner).toUint();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view virtual nonReentrantView returns (uint256) {
        return convertToAssets(shares); // Doesn't take into account the `shares == type(uint256).max` case
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

        Assets assets =
            amount == type(uint256).max ? marketCache.asset.balanceOf(account).toAssets() : amount.toAssets(); // A small digression from the standard, but acceptable imho
        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        finalizeDeposit(marketCache, assets, shares, account, receiver);

        return shares.toUint();
    }

    /// @inheritdoc IERC4626
    function mint(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_MINT, ACCOUNTCHECK_NONE);

        Shares shares = amount.toShares();
        if (shares.isZero()) return 0;

        Assets assets = shares.toAssetsUp(marketCache);
        // We don't need to check assets.isZero() and revert because we round up

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

        Assets assets = amount.toAssets();
        if (assets.isZero()) return 0;

        Shares shares = assets.toSharesUp(marketCache);
        // We don't need to check shares.isZero() and revert because we round up

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);

        return shares.toUint();
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 amount, address receiver, address owner) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_REDEEM, owner);

        Shares shares = amount == type(uint256).max ? marketStorage.users[owner].getBalance() : amount.toShares(); // A small digression from the standard, but acceptable imho
        if (shares.isZero()) return 0;

        Assets assets = shares.toAssetsDown(marketCache);
        if (assets.isZero()) revert E_ZeroAssets();

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);

        return assets.toUint();
    }

    /// @inheritdoc IVault
    function skim(uint256 amount, address receiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_SKIM, ACCOUNTCHECK_NONE);

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
        marketStorage.cash = marketCache.cash = marketCache.cash + assets;

        return shares.toUint();
    }

    function finalizeDeposit(
        MarketCache memory marketCache,
        Assets assets,
        Shares shares,
        address sender,
        address receiver
    ) private {
        // This function wouldn't know if it is being told to commit an inconsistent state to storage with regards to the assets
        // and shares amounts, and would commit it. The Morpho Blue implementation is more robust. In it, exactly one of `assets`
        // or `shares` must be zero, and the other is calculated within this function.
        pullAssets(marketCache, sender, assets);

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
        // This function wouldn't know if it is being told to commit an inconsistent state to storage with regards to the assets
        // and shares amounts, and would commit it. The Morpho Blue implementation is more robust. In it, exactly one of `assets`
        // or `shares` must be zero, and the other is calculated within this function.
        if (marketCache.cash < assets) revert E_InsufficientCash();

        decreaseAllowance(owner, sender, shares);
        decreaseBalance(marketCache, owner, sender, receiver, shares, assets);

        pushAssets(marketCache, receiver, assets);
    }

    function maxRedeemInternal(address owner) internal view returns (Shares) {
        Shares max = marketStorage.users[owner].getBalance();
        if (max.isZero()) return max;

        // When checks are deferred, all of the balance can be withdrawn, even if only temporarily
        if (!isAccountStatusCheckDeferred(owner)) { // If account checks are expected, the user can withdraw all of his balance
            address controller = getController(owner);

            if (controller != address(0)) {
                (bool success, bytes memory data) = controller.staticcall(abi.encodeCall(IBorrowing.collateralUsed, (address(this), owner)));
                // if controller doesn't implement the function, assume it will not block withdrawal
                if (success) {
                    uint256 used = abi.decode(data, (uint256));
                    if (used >= max.toUint()) return Shares.wrap(0);
                    max = max - used.toShares(); // If account checks are not expected, the user can withdraw what he doesn't use
                }
            }
        }

        MarketCache memory marketCache = loadMarket();

        Shares cash = marketCache.cash.toSharesDown(marketCache); // What the user can withdraw is capped by what the vault is holding
        max = max > cash ? cash : max;

        return max;
    }

    function maxDepositInternal(MarketCache memory marketCache, address) private view returns (uint256) {
        uint remainingSupply;

        // In transient state with vault status checks deferred, supply caps will not be immediately enforced
        if (isVaultStatusCheckDeferred()) { // `isVaultStatusCheckDeferred` is a bit misleading, it should be `isVaultStatusCheckQueued` or `isVaultStatusCheckExpected`
            // Won't this be a bit misleading? I ask if I can deposit an amount of PEPE, got told yes but then at the end
            // the transaction reverts because we surpassed the supply cap.
            remainingSupply = type(uint256).max;
        } else {
            uint256 supply = totalAssetsInternal(marketCache); // Total assets are cash + debt
            if(supply >= marketCache.supplyCap) return 0;

            remainingSupply = marketCache.supplyCap - supply; // We calculate the room left until the supply cap
        }

        uint256 remainingCash = MAX_SANE_AMOUNT - marketCache.cash.toUint(); // Supply cap < MAX_SANE_AMOUNT && totalAssetsInternal > marketCache.cash

        // If vault checks are expected, remainingSupply = type(uint256).max, else remainingSupply is the room to the supply cap
        // remainingCash is the room in the cash holdings up to the maximum manageable amount
        // The only situation in which remainingCash < remainingSupply is if isVaultStatusCheckDeferred == true
        // because marketCache.supplyCap - (cash + debt) < MAX_SANE_AMOUNT - cash
        return remainingCash < remainingSupply ? remainingCash : remainingSupply;
    }

    function maxDepositInternalAlternate(MarketCache memory marketCache, address) private view returns (uint256) {
        uint remainingSupply;

        // In transient state with vault status checks deferred, supply caps will not be immediately enforced
        if (isVaultStatusCheckDeferred()) {
            return MAX_SANE_AMOUNT - marketCache.cash.toUint(); // Return the availability to hold cash.
        } else {
            uint256 supply = totalAssetsInternal(marketCache);
            if(supply >= marketCache.supplyCap) return 0;

            return marketCache.supplyCap - supply; // Return the availability up to the supply cap.
        }
    }
}

contract Vault is VaultModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

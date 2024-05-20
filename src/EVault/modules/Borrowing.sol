// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";
import {IFlashLoan} from "../../interfaces/IFlashLoan.sol";

import "../shared/types/Types.sol";

/// @title BorrowingModule
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An EVault module handling borrowing and repaying of vault assets
abstract contract BorrowingModule is IBorrowing, Base, AssetTransfers, BalanceUtils, LiquidityUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IBorrowing
    function totalBorrows() public view virtual nonReentrantView returns (uint256) {
        return loadVault().totalBorrows.toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() public view virtual nonReentrantView returns (uint256) {
        return loadVault().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function cash() public view virtual nonReentrantView returns (uint256) {
        return vaultStorage.cash.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) public view virtual nonReentrantView returns (uint256) {
        return getCurrentOwed(loadVault(), account).toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOfExact(address account) public view virtual nonReentrantView returns (uint256) {
        return getCurrentOwed(loadVault(), account).toUint();
    }

    /// @inheritdoc IBorrowing
    function interestRate() public view virtual nonReentrantView returns (uint256) {
        return computeInterestRateView(loadVault());
    }

    /// @inheritdoc IBorrowing
    function interestAccumulator() public view virtual nonReentrantView returns (uint256) {
        return loadVault().interestAccumulator;
    }

    /// @inheritdoc IBorrowing
    function dToken() public view virtual reentrantOK returns (address) {
        return calculateDTokenAddress();
    }

    /// @inheritdoc IBorrowing
    function borrow(uint256 amount, address receiver) public virtual nonReentrant returns (uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_BORROW, CHECKACCOUNT_CALLER);

        Assets assets = amount == type(uint256).max ? vaultCache.cash : amount.toAssets();
        if (assets.isZero()) return 0;

        if (assets > vaultCache.cash) revert E_InsufficientCash();

        increaseBorrow(vaultCache, account, assets);

        pushAssets(vaultCache, receiver, assets);

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function repay(uint256 amount, address receiver) public virtual nonReentrant returns (uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_REPAY, CHECKACCOUNT_NONE);

        uint256 owed = getCurrentOwed(vaultCache, receiver).toAssetsUp().toUint();

        Assets assets = (amount == type(uint256).max ? owed : amount).toAssets();
        if (assets.isZero()) return 0;

        pullAssets(vaultCache, account, assets);

        decreaseBorrow(vaultCache, receiver, assets);

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function loop(uint256 amount, address sharesReceiver) public virtual nonReentrant returns (uint256, uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_LOOP, CHECKACCOUNT_CALLER);

        Assets assets = amount.toAssets();
        if (assets.isZero()) return (0, 0);

        // The debt and shares minted should match the current exchange rate from shares to assets.
        // First round the requested amount up to shares, to avoid zero shares.
        // Next convert back to assets, again rounding up the debt in favor of the vault.
        // As a result the amount of debt minted can be greater than amount requested.
        Shares shares = assets.toSharesUp(vaultCache);
        assets = shares.toAssetsUp(vaultCache);

        // Mint DTokens
        increaseBorrow(vaultCache, account, assets);

        // Mint ETokens
        increaseBalance(vaultCache, sharesReceiver, account, shares, assets);

        return (shares.toUint(), assets.toUint());
    }

    /// @inheritdoc IBorrowing
    function deloop(uint256 amount, address debtFrom) public virtual nonReentrant returns (uint256, uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_DELOOP, CHECKACCOUNT_CALLER);

        Assets owed = getCurrentOwed(vaultCache, debtFrom).toAssetsUp();
        if (owed.isZero()) return (0, 0);

        Assets assets;
        Shares shares;

        if (amount == type(uint256).max) {
            shares = vaultStorage.users[account].getBalance();
            assets = shares.toAssetsDown(vaultCache);
        } else {
            assets = amount.toAssets();
            shares = assets.toSharesUp(vaultCache);
        }

        if (assets.isZero()) return (0, 0);

        if (assets > owed) {
            assets = owed;
            shares = assets.toSharesUp(vaultCache);
        }

        // Burn ETokens
        decreaseBalance(vaultCache, account, account, account, shares, assets);

        // Burn DTokens
        decreaseBorrow(vaultCache, debtFrom, assets);

        return (shares.toUint(), assets.toUint());
    }

    /// @inheritdoc IBorrowing
    function pullDebt(uint256 amount, address from) public virtual nonReentrant returns (uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_PULL_DEBT, CHECKACCOUNT_CALLER);

        if (from == account) revert E_SelfTransfer();

        Assets assets = amount == type(uint256).max ? getCurrentOwed(vaultCache, from).toAssetsUp() : amount.toAssets();

        if (assets.isZero()) return 0;
        transferBorrow(vaultCache, from, account, assets);

        emit PullDebt(from, account, assets.toUint());

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function flashLoan(uint256 amount, bytes calldata data) public virtual nonReentrant {
        address account = EVCAuthenticate();
        callHook(vaultStorage.hookedOps, OP_FLASHLOAN, account);

        (IERC20 asset,,) = ProxyUtils.metadata();

        uint256 origBalance = asset.balanceOf(address(this));

        asset.safeTransfer(account, amount);

        IFlashLoan(account).onFlashLoan(data);

        if (asset.balanceOf(address(this)) < origBalance) revert E_FlashLoanNotRepaid();
    }

    /// @inheritdoc IBorrowing
    function touch() public virtual nonReentrant {
        initOperation(OP_TOUCH, CHECKACCOUNT_NONE);
    }
}

/// @dev Deployable module contract
contract Borrowing is BorrowingModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

abstract contract BorrowingModule is IBorrowing, Base, AssetTransfers, BalanceUtils, BorrowUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;
    using UserStorageLib for UserStorage;

    /// @inheritdoc IBorrowing
    function totalBorrows() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.totalBorrows.toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function poolSize() external view virtual nonReentrantView returns (uint256) {
        return marketStorage.poolSize.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return getCurrentOwed(marketCache, account).toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOfExact(address account) external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return getCurrentOwed(marketCache, account).toUint();
    }

    /// @inheritdoc IBorrowing
    function interestRate() external view virtual reentrantOK returns (uint72) {
        if (isVaultStatusCheckDeferred()) revert E_VaultStatusCheckDeferred();

        return marketStorage.interestRate;
    }

    /// @inheritdoc IBorrowing
    function interestAccumulator() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().interestAccumulator;
    }

    /// @inheritdoc IBorrowing
    function collateralBalanceLocked(address collateral, address account)
        external
        view
        virtual
        nonReentrantView
        returns (uint256)
    {
        if (getController(account) != address(this)) revert E_ControllerDisabled();
        MarketCache memory marketCache = loadMarket();

        return
            marketCache.riskManager.collateralBalanceLocked(collateral, account, getRMLiability(marketCache, account));
    }

    /// @inheritdoc IBorrowing
    function riskManager() external view virtual reentrantOK returns (address) {
        (, IRiskManager rm) = ProxyUtils.metadata();
        return address(rm);
    }

    /// @inheritdoc IBorrowing
    function dToken() external view virtual reentrantOK returns (address) {
        return calculateDTokenAddress();
    }

    /// @inheritdoc IBorrowing
    function getEVC() external view virtual reentrantOK returns (address) {
        return address(evc);
    }

    /// @inheritdoc IBorrowing
    function borrow(uint256 amount, address receiver) external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperationForBorrow(OP_BORROW);

        if (receiver == address(0)) receiver = getAccountOwner(account);

        Assets assets = amount == type(uint256).max ? marketCache.poolSize : amount.toAssets();
        if (assets.isZero()) return;

        if (assets > marketCache.poolSize) revert E_InsufficientPoolSize();

        increaseBorrow(marketCache, account, assets);

        pushTokens(marketCache, receiver, assets);
    }

    /// @inheritdoc IBorrowing
    function repay(uint256 amount, address receiver) external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_REPAY, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        uint256 owed = getCurrentOwed(marketCache, receiver).toAssetsUp().toUint();
        if (owed == 0) return;

        Assets assets = (amount > owed ? owed : amount).toAssets();
        if (assets.isZero()) return;

        pullTokens(marketCache, account, assets);

        decreaseBorrow(marketCache, receiver, assets);
    }

    /// @inheritdoc IBorrowing
    function wind(uint256 amount, address sharesReceiver) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperationForBorrow(OP_WIND);

        if (sharesReceiver == address(0)) sharesReceiver = account;

        Assets assets = amount.toAssets();
        if (assets.isZero()) return 0;
        Shares shares = assets.toSharesUp(marketCache);
        assets = shares.toAssetsUp(marketCache);

        // Mint DTokens
        increaseBorrow(marketCache, account, assets);

        // Mint ETokens
        increaseBalance(marketCache, sharesReceiver, account, shares, assets);

        return shares.toUint();
    }

    /// @inheritdoc IBorrowing
    function unwind(uint256 amount, address debtFrom) external virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_UNWIND, ACCOUNTCHECK_CALLER);

        if (debtFrom == address(0)) debtFrom = account;

        Assets owed = getCurrentOwed(marketCache, debtFrom).toAssetsUp();
        if (owed.isZero()) return 0;

        Assets assets;
        Shares shares;

        if (amount == type(uint256).max) {
            shares = marketStorage.users[account].getBalance();
            assets = shares.toAssetsDown(marketCache);
        } else {
            assets = amount.toAssets();
            shares = assets.toSharesUp(marketCache);
        }

        if (assets.isZero()) return 0;

        if (assets > owed) {
            assets = owed;
            shares = assets.toSharesUp(marketCache);
        }

        // Burn ETokens
        decreaseBalance(marketCache, account, account, account, shares, assets);

        // Burn DTokens
        decreaseBorrow(marketCache, debtFrom, assets);

        return shares.toUint();
    }

    /// @inheritdoc IBorrowing
    function pullDebt(uint256 amount, address from) external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperationForBorrow(OP_PULL_DEBT);

        if (from == account) revert E_SelfTransfer();

        Assets assets = amount == type(uint256).max ? getCurrentOwed(marketCache, from).toAssetsUp() : amount.toAssets();

        if (assets.isZero()) return;
        transferBorrow(marketCache, from, account, assets);
    }

    /// @inheritdoc IBorrowing
    function touch() external virtual nonReentrant {
        initOperation(OP_TOUCH, ACCOUNTCHECK_NONE);
    }

    /// @inheritdoc IBorrowing
    function flashLoan(uint256 assets, bytes calldata data) external virtual nonReentrant {
        (IERC20 asset_,) = ProxyUtils.metadata();
        address account = EVCAuthenticate();

        uint256 origBalance = asset_.balanceOf(address(this));

        asset_.safeTransfer(account, assets);

        IFlashLoan(account).onFlashLoan(data);

        if (asset_.balanceOf(address(this)) < origBalance) revert E_FlashLoanNotRepaid();
    }

    /// @inheritdoc IBorrowing
    function disableController() external virtual nonReentrant {
        address account = EVCAuthenticate();

        if (!marketStorage.users[account].getOwed().isZero()) revert E_OutstandingDebt();

        disableControllerInternal(account);
    }

    /// @inheritdoc IBorrowing
    /// @dev The function doesn't have a re-entrancy lock, because onlyEVCChecks provides equivalent behaviour. It ensures that the caller
    /// is the EVC, in 'checks in progress' state. In this state EVC will not accept any calls. Since all the functions which modify
    /// vault state use callThroughEVC modifier, they are effectively blocked while the function executes. There are non-view functions without
    /// callThroughEVC modifier (`flashLoan`, `disableCollateral`, `skimAssets`), but they don't change the vault's storage.
    function checkAccountStatus(address account, address[] calldata collaterals)
        public
        virtual
        reentrantOK
        onlyEVCChecks
        returns (bytes4 magicValue)
    {
        MarketCache memory marketCache = loadMarket();
        marketCache.riskManager.checkAccountStatus(account, collaterals, getRMLiability(marketCache, account));
        magicValue = ACCOUNT_STATUS_CHECK_RETURN_VALUE;
    }

    /// @inheritdoc IBorrowing
    /// @dev See comment about re-entrancy for `checkAccountStatus`
    function checkVaultStatus() public virtual reentrantOK onlyEVCChecks returns (bytes4 magicValue) {
        // Use the updating variant to make sure interest is accrued in storage before the interest rate update
        MarketCache memory marketCache = updateMarket();
        uint72 newInterestRate = updateInterestParams(marketCache);

        logMarketStatus(marketCache, newInterestRate);

        MarketSnapshot memory currentSnapshot = getMarketSnapshot(0, marketCache);
        MarketSnapshot memory oldSnapshot = marketStorage.marketSnapshot;
        delete marketStorage.marketSnapshot.performedOperations;

        if (oldSnapshot.performedOperations == 0) revert E_InvalidSnapshot();

        marketCache.riskManager.checkMarketStatus(
            address(this),
            oldSnapshot.performedOperations,
            IRiskManager.Snapshot({
                poolSize: oldSnapshot.poolSize.toUint(),
                totalBorrows: oldSnapshot.totalBorrows.toUint()
            }),
            IRiskManager.Snapshot({
                poolSize: currentSnapshot.poolSize.toUint(),
                totalBorrows: currentSnapshot.totalBorrows.toUint()
            })
        );

        magicValue = VAULT_STATUS_CHECK_RETURN_VALUE;
    }
}

contract Borrowing is BorrowingModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}

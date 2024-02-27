// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

import "../shared/types/Types.sol";

/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

abstract contract BorrowingModule is IBorrowing, Base, AssetTransfers, BalanceUtils, LiquidityUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

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
    function collateralUsed(address collateral, address account)
        external
        view
        virtual
        nonReentrantView
        returns (uint256)
    {
        if (getController(account) != address(this)) revert E_ControllerDisabled();

        // if collateral is not enabled, it will not be locked
        if (!isCollateralEnabled(account, collateral)) return 0;

        address[] memory collaterals = getCollaterals(account);
        MarketCache memory marketCache = loadMarket();
        (uint256 totalCollateralValueRiskAdjusted, uint256 liabilityValue) = liquidityCalculate(marketCache, account, collaterals, false);

        // if there is no liability or it has no value, collateral will not be locked
        if (liabilityValue == 0) return 0;

        uint256 collateralBalance = IERC20(collateral).balanceOf(account);

        // if account is not healthy, all of the collateral will be locked
        if (liabilityValue >= totalCollateralValueRiskAdjusted) {
            return collateralBalance;
        }

        // if collateral has zero LTV configured, it will not be locked
        uint256 ltv = ltvLookup[collateral].getLTV();
        if (ltv == 0) return 0;

        // calculate extra collateral value in terms of requested collateral shares (balance)
        uint256 extraCollateralValue = (totalCollateralValueRiskAdjusted - liabilityValue) * CONFIG_SCALE / ltv;

        uint256 extraCollateralBalance;
        {
            // TODO use direct quote (below) when oracle supports both directions
            // uint extraCollateralBalance = IPriceOracle(oracle).getQuote(extraCollateralValue, referenceAsset, collateral);

            uint256 collateralPrice = marketCache.oracle.getQuote(1e18, collateral, marketCache.unitOfAccount);
            if (collateralPrice == 0) return 0; // worthless / unpriced collateral is not locked TODO what happens in liquidation??
            extraCollateralBalance = extraCollateralValue * 1e18 / collateralPrice;
        }

        if (extraCollateralBalance >= collateralBalance) return 0; // other collaterals are sufficient to support the debt

        return collateralBalance - extraCollateralBalance;
    }

    /// @inheritdoc IBorrowing
    function dToken() external view virtual reentrantOK returns (address) {
        return calculateDTokenAddress();
    }

    /// @inheritdoc IBorrowing
    function EVC() external view virtual reentrantOK returns (address) {
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
    function loop(uint256 amount, address sharesReceiver) external virtual nonReentrant returns (uint256) {
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
    function deloop(uint256 amount, address debtFrom) external virtual nonReentrant returns (uint256) {
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
        if (marketStorage.disabledOps.get(OP_FLASHLOAN)) {
            revert E_OperationDisabled();
        }

        (IERC20 asset,,) = ProxyUtils.metadata();
        address account = EVCAuthenticate();

        uint256 origBalance = asset.balanceOf(address(this));

        asset.safeTransfer(account, assets);

        IFlashLoan(account).onFlashLoan(data);

        if (asset.balanceOf(address(this)) < origBalance) revert E_FlashLoanNotRepaid();
    }
}

contract Borrowing is BorrowingModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IBorrowing} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";
import {AssetTransfers} from "../shared/AssetTransfers.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}

abstract contract BorrowingModule is IBorrowing, Base, AssetTransfers, BalanceUtils, LiquidityUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IBorrowing
    function totalBorrows() public view virtual nonReentrantView returns (uint256) {
        return loadMarket().totalBorrows.toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function totalBorrowsExact() public view virtual nonReentrantView returns (uint256) {
        return loadMarket().totalBorrows.toUint();
    }

    /// @inheritdoc IBorrowing
    function cash() public view virtual nonReentrantView returns (uint256) {
        return marketStorage.cash.toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOf(address account) public view virtual nonReentrantView returns (uint256) {
        return getCurrentOwed(loadMarket(), account).toAssetsUp().toUint();
    }

    /// @inheritdoc IBorrowing
    function debtOfExact(address account) public view virtual nonReentrantView returns (uint256) {
        return getCurrentOwed(loadMarket(), account).toUint();
    }

    /// @inheritdoc IBorrowing
    function interestRate() public view virtual nonReentrantView returns (uint256) {
        return computeInterestRateView(loadMarket());
    }

    /// @inheritdoc IBorrowing
    function interestAccumulator() public view virtual nonReentrantView returns (uint256) {
        return loadMarket().interestAccumulator;
    }

    /// @inheritdoc IBorrowing
    function collateralUsed(address collateral, address account)
        public
        view
        virtual
        nonReentrantView
        returns (uint256)
    {
        verifyController(account);

        // if collateral is not enabled, it will not be locked
        if (!isCollateralEnabled(account, collateral)) return 0;

        address[] memory collaterals = getCollaterals(account);
        MarketCache memory marketCache = loadMarket();
        (uint256 totalCollateralValueRiskAdjusted, uint256 liabilityValue) = calculateLiquidity(marketCache, account, collaterals, LTVType.BORROWING);

        // if there is no liability or it has no value, collateral will not be locked
        if (liabilityValue == 0) return 0;

        uint256 collateralBalance = IERC20(collateral).balanceOf(account);

        // if account is not healthy, all of the collateral will be locked
        if (liabilityValue >= totalCollateralValueRiskAdjusted) {
            return collateralBalance;
        }

        // if collateral has zero LTV configured, it will not be locked
        ConfigAmount ltv = getLTV(collateral, LTVType.BORROWING);
        if (ltv.isZero()) return 0;

        // calculate value of unused collateral in unit of account terms. We divide by LTV because `calculateLiquidity` returns a LTV-adjusted collateral value
        uint256 extraCollateralValue = ltv.mulInv(totalCollateralValueRiskAdjusted - liabilityValue); // (coll*ltv - debt)/ltv

        // convert back to collateral balance (bid)
        (uint256 collateralPrice,) = marketCache.oracle.getQuotes(1e18, collateral, marketCache.unitOfAccount); // Are we assuming that the unit of account has 18 decimals?
        if (collateralPrice == 0) return 0; // worthless / unpriced collateral is not locked
        uint256 extraCollateralBalance = extraCollateralValue * 1e18 / collateralPrice; // Actually, since we asked for the value of 1e18 collateral in unit of account, this will just work even if the unit of account is USD with 8 decimals.

        // You can also do:
        // convert unused collateral amount to unit of account terms
        // (uint256 extraCollateralBalance,) = marketCache.oracle.getQuotes(extraCollateralValue, marketCache.unitOfAccount, collateral);
        // if (extraCollateralBalance == 0) return 0; // If this collateral is worthless or unpriced collateral then it is not locked

        if (extraCollateralBalance >= collateralBalance) return 0; // The user held amount of this collateral is below the user held amount of unused collateral, so all of it is considered unused

        return collateralBalance - extraCollateralBalance;
    }

    /// @inheritdoc IBorrowing
    function dToken() public view virtual reentrantOK returns (address) {
        return calculateDTokenAddress();
    }


    /// @inheritdoc IBorrowing
    function borrow(uint256 amount, address receiver) public virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_BORROW, CHECKACCOUNT_CALLER);

        Assets assets = amount == type(uint256).max ? marketCache.cash : amount.toAssets();
        if (assets.isZero()) return 0;

        if (assets > marketCache.cash) revert E_InsufficientCash();

        increaseBorrow(marketCache, account, assets);

        pushAssets(marketCache, receiver, assets);

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function repay(uint256 amount, address receiver) public virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_REPAY, CHECKACCOUNT_NONE);

        uint256 owed = getCurrentOwed(marketCache, receiver).toAssetsUp().toUint();

        Assets assets = (amount == type(uint256).max ? owed : amount).toAssets();
        if (assets.isZero()) return 0;

        pullAssets(marketCache, account, assets);

        decreaseBorrow(marketCache, receiver, assets);

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function loop(uint256 amount, address sharesReceiver) public virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_LOOP, CHECKACCOUNT_CALLER);

        Assets assets = amount.toAssets();
        if (assets.isZero()) return 0;
        Shares shares = assets.toSharesUp(marketCache); // This is to mint eTokens, or shares on the underlying deposits. Shouldn't this round down?
        assets = shares.toAssetsUp(marketCache); // Why do we convert back to assets?

        // Mint DTokens
        increaseBorrow(marketCache, account, assets);

        // Mint ETokens
        increaseBalance(marketCache, sharesReceiver, account, shares, assets);

        return shares.toUint();
    }

    /// @inheritdoc IBorrowing
    function deloop(uint256 amount, address debtFrom) public virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_DELOOP, CHECKACCOUNT_NONE);

        Assets owed = getCurrentOwed(marketCache, debtFrom).toAssetsUp();
        if (owed.isZero()) return 0;

        Assets assets;
        Shares shares;

        if (amount == type(uint256).max) {
            shares = marketStorage.users[account].getBalance();
            assets = shares.toAssetsDown(marketCache); // Assets is the debt that will be reduced, rounding down is in favour of the vault
        } else {
            assets = amount.toAssets();
            shares = assets.toSharesUp(marketCache); // Shares are the vault shares that will be burned, rounding up is in favour of the vault
        }

        if (assets.isZero()) return 0;

        // If the user requested to repay more debt than they hold, we repay all debt
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
    // We don't have a `pushDebt` function, and that is probably a good thing.
    // Sometimes I wonder about what would happen in tradfi if people could just pull debt from anyone without asking for permission.
    function pullDebt(uint256 amount, address from) public virtual nonReentrant returns (uint256) {
        (MarketCache memory marketCache, address account) = initOperation(OP_PULL_DEBT, CHECKACCOUNT_CALLER);

        if (from == account) revert E_SelfTransfer();

        Assets assets = amount == type(uint256).max ? getCurrentOwed(marketCache, from).toAssetsUp() : amount.toAssets(); // getCurrentOwed(marketCache, from).toAssetsUp() rounds up above the actual owed amount, but `transferBorrow` will tweak the parameter received down to the actual owed amount if that was the case.

        if (assets.isZero()) return 0;
        transferBorrow(marketCache, from, account, assets);

        return assets.toUint();
    }

    /// @inheritdoc IBorrowing
    function flashLoan(uint256 amount, bytes calldata data) public virtual nonReentrant {
        if (marketStorage.disabledOps.check(OP_FLASHLOAN)) {
            revert E_OperationDisabled();
        }

        (IERC20 asset,,) = ProxyUtils.metadata();
        address account = EVCAuthenticate();

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

contract Borrowing is BorrowingModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

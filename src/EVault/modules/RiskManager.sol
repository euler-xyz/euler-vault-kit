// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRiskManager, IEVault} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../interestRateModels/IIRM.sol";

import "../shared/types/Types.sol";

abstract contract RiskManagerModule is IRiskManager, Base, BorrowUtils {
    using TypesLib for uint256;

    /// @inheritdoc IRiskManager
    function computeAccountLiquidity(address account) external virtual view returns (uint256 collateralValue, uint256 liabilityValue) {
        MarketCache memory marketCache = loadMarket();

        verifyController(account);
        address[] memory collaterals = IEVC(evc).getCollaterals(account);

        return computeLiquidity(
            marketCache,
            account,
            collaterals
        );
    }

    /// @inheritdoc IRiskManager
    function computeAccountLiquidityPerMarket(address account) external virtual view returns (MarketLiquidity[] memory) {
        MarketCache memory marketCache = loadMarket();

        verifyController(account);
        address[] memory collaterals = IEVC(evc).getCollaterals(account);

        uint256 numMarkets = collaterals.length + 1;
        for (uint256 i; i < collaterals.length; ++i) {
            if (collaterals[i] == address(this)) {
                numMarkets--;
                break;
            }
        }

        MarketLiquidity[] memory output = new MarketLiquidity[](numMarkets);
        address[] memory singleCollateral = new address[](1);

        // account also supplies collateral in liability market
        for (uint256 i; i < collaterals.length; ++i) {
            output[i].market = collaterals[i];
            singleCollateral[0] = collaterals[i];

            (output[i].collateralValue, output[i].liabilityValue) =
                computeLiquidity(marketCache, account, singleCollateral);
            if (collaterals[i] != address(this)) output[i].liabilityValue = 0;
        }

        // liability market is not included in supplied collaterals
        if (numMarkets > collaterals.length) {
            singleCollateral[0] = address(this);
            uint256 index = numMarkets - 1;

            output[index].market = address(this);
            (output[index].collateralValue, output[index].liabilityValue) =
                computeLiquidity(marketCache, account, singleCollateral);
        }

        return output;
    }

    /// @inheritdoc IRiskManager
    function disableController() external virtual nonReentrant {
        address account = EVCAuthenticate();

        if (!marketStorage.users[account].getOwed().isZero()) revert E_OutstandingDebt();

        disableControllerInternal(account);
    }

    /// @inheritdoc IRiskManager
    /// @dev The function doesn't have a re-entrancy lock, because onlyEVCChecks provides equivalent behaviour. It ensures that the caller
    /// is the EVC, in 'checks in progress' state. In this state EVC will not accept any calls. Since all the functions which modify
    /// vault state use callThroughEVC modifier, they are effectively blocked while the function executes. There are non-view functions without
    /// callThroughEVC modifier (`flashLoan`, `disableCollateral`, `skimAssets`), but they don't change the vault's storage.
    function checkAccountStatus(address account, address[] calldata collaterals)
        external
        virtual
        reentrantOK
        onlyEVCChecks
        returns (bytes4 magicValue)
    {
        MarketCache memory marketCache = loadMarket();

        if (!marketStorage.users[account].getOwed().isZero()) {
            (uint256 collateralValue, uint256 liabilityValue) = computeLiquidity(marketCache, account, collaterals);
            if (collateralValue < liabilityValue) revert RM_AccountLiquidity();
        }

        magicValue = ACCOUNT_STATUS_CHECK_RETURN_VALUE;
    }

    /// @inheritdoc IRiskManager
    /// @dev See comment about re-entrancy for `checkAccountStatus`
    function checkVaultStatus() external virtual reentrantOK onlyEVCChecks returns (bytes4 magicValue) {
        // Use the updating variant to make sure interest is accrued in storage before the interest rate update
        MarketCache memory marketCache = updateMarket();
        uint72 newInterestRate = updateInterestRate(marketCache);

        logMarketStatus(marketCache, newInterestRate);

        // If snapshot is initialized, then caps are configured.
        // If caps are set in the middle of a batch, then snapshots represent the state of the vault at that time.
        if (marketCache.snapshotInitialized) {
            marketStorage.snapshotInitialized = marketCache.snapshotInitialized = false;

            uint256 prevBorrows = snapshotTotalBorrows.toUint();
            uint256 borrows = marketCache.totalBorrows.toAssetsUp().toUint();

            if (borrows > marketCache.borrowCap && borrows > prevBorrows) revert E_BorrowCapExceeded();

            uint256 prevSupply = snapshotPoolSize.toUint() + prevBorrows;
            uint256 supply = totalAssetsInternal(marketCache);

            if (supply > marketCache.supplyCap && supply > prevSupply) revert E_SupplyCapExceeded();
        }

        magicValue = VAULT_STATUS_CHECK_RETURN_VALUE;
    }

    function updateInterestRate(MarketCache memory marketCache) private returns (uint72) {
        uint256 newInterestRate;

        // single SLOAD
        address irm = marketStorage.interestRateModel;
        uint16 interestFee = marketStorage.interestFee;

        if (irm != address(0)) {
            uint256 borrows = marketCache.totalBorrows.toAssetsUp().toUint();
            uint256 poolAssets = marketCache.poolSize.toUint() + borrows;

            uint32 utilisation = poolAssets == 0
                ? 0 // empty pool arbitrarily given utilisation of 0
                : uint32(borrows * (uint256(type(uint32).max) * 1e18) / poolAssets / 1e18);

            try IIRM(irm).computeInterestRate(msg.sender, address(marketCache.asset), utilisation) returns (uint256 ir) {
                newInterestRate = ir;
            } catch {}
        }

        if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;

        // single SSTORE
        marketStorage.interestRateModel = irm;
        marketStorage.interestFee = interestFee;
        marketStorage.interestRate = uint72(newInterestRate);

        return uint72(newInterestRate);
    }

    function verifyController(address account) private view {
        address[] memory controllers = IEVC(evc).getControllers(account);

        if (controllers.length > 1) revert RM_TransientState();
        if (controllers.length == 0) revert RM_NoLiability();
        if (controllers[0] != address(this)) revert RM_NotController();
    }
}

contract RiskManager is RiskManagerModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

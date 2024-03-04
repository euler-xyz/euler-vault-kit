// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRiskManager, IEVault} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";
import "../../interestRateModels/IIRM.sol";

import "../shared/types/Types.sol";

abstract contract RiskManagerModule is IRiskManager, Base, LiquidityUtils {
    using TypesLib for uint256;

    /// @inheritdoc IRiskManager
    function accountLiquidity(address account, bool liquidation) external view virtual nonReentrantView returns (uint256 collateralValue, uint256 liabilityValue) {
        MarketCache memory marketCache = loadMarket();

        verifyController(account);
        address[] memory collaterals = getCollaterals(account);

        return liquidityCalculate(
            marketCache,
            account,
            collaterals,
            liquidation
        );
    }

    /// @inheritdoc IRiskManager
    function accountLiquidityFull(address account, bool liquidation) external view virtual nonReentrantView returns (address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue) {
        verifyController(account);
        MarketCache memory marketCache = loadMarket();

        verifyController(account); // alcueca: We probably don't need to verufy the contrller twice
        collaterals = getCollaterals(account);
        collateralValues = new uint256[](collaterals.length);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValues[i] = getCollateralValue(marketCache, account, collaterals[i], liquidation);
        }

        liabilityValue = getLiabilityValue(marketCache, account);
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
        liquidityCheck(account, collaterals);

        magicValue = ACCOUNT_STATUS_CHECK_RETURN_VALUE;
    }

    /// @inheritdoc IRiskManager
    /// @dev See comment about re-entrancy for `checkAccountStatus`
    function checkVaultStatus() external virtual reentrantOK onlyEVCChecks returns (bytes4 magicValue) {
        // alcueca: Hijack the vault status check to make sure that the market storage is updated at the end of the batch
        // Use the updating variant to make sure interest is accrued in storage before the interest rate update
        MarketCache memory marketCache = updateMarket();
        uint72 newInterestRate = updateInterestRate(marketCache); // alcueca: Better to always use uint256 internally

        logMarketStatus(marketCache, newInterestRate); // alcueca: You can convert to uint72 inside `logMarketStatus`, if you need to.

        // alcueca: We use the snapshot to check if the borrows or supply grew, and if so then we check the borrow and supply caps.
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

    function updateInterestRate(MarketCache memory marketCache) private returns (uint72) { // alcueca: Better to always use uint256 internally
        uint256 newInterestRate;

        // single SLOAD
        address irm = marketStorage.interestRateModel;
        uint16 interestFee = marketStorage.interestFee; // alcueca: Even if you are not going to use it, I would pull this as a uint256 and cast it back at the end, for consistency

        if (irm != address(0)) {
            uint256 borrows = marketCache.totalBorrows.toAssetsUp().toUint(); // alcueca: Is there some rule as to whether amounts are in assets or shares in marketCache/marketStorage?
            uint256 poolAssets = marketCache.poolSize.toUint() + borrows; // alcueca: poolSize and poolAssets is a bit obscure. vaultAssets and vaultAssetsAndBorrows is a bit clearer.

            uint32 utilisation = poolAssets == 0
                ? 0 // empty pool arbitrarily given utilisation of 0
                : uint32(borrows * (uint256(type(uint32).max) * 1e18) / poolAssets / 1e18); // alcueca: type(uint32).max used to maximize the uint32 for maximum precision (borrows/poolAssets < 1). Why not just `borrows * type(uint32).max / poolAssets`? I got tripped by `poolAssets` yet once again :/

            try IIRM(irm).computeInterestRate(address(this), address(marketCache.asset), utilisation) returns (uint256 ir) {
                newInterestRate = ir; // alcueca: If the IRM reverts the new interest rate is zero?
            } catch {} // alcueca: Cool kids use (success, result)
        }

        if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;

        // single SSTORE
        marketStorage.interestRateModel = irm;
        marketStorage.interestFee = minterestFee;
        marketStorage.interestRate = uint72(newInterestRate); // alcueca: Correct, here is where you convert from uint256 to uint72

        return uint72(newInterestRate);
    }
}

contract RiskManager is RiskManagerModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

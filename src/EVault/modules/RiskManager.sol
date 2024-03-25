// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRiskManager} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {LiquidityUtils} from "../shared/LiquidityUtils.sol";

import "../shared/types/Types.sol";

abstract contract RiskManagerModule is IRiskManager, Base, LiquidityUtils {
    using TypesLib for uint256;

    /// @inheritdoc IRiskManager
    function accountLiquidity(address account, bool liquidation)
        public
        view
        virtual
        nonReentrantView
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        VaultCache memory vaultCache = loadVault();

        validateController(account);
        address[] memory collaterals = getCollaterals(account);

        return
            calculateLiquidity(vaultCache, account, collaterals, liquidation ? LTVType.LIQUIDATION : LTVType.BORROWING);
    }

    /// @inheritdoc IRiskManager
    function accountLiquidityFull(address account, bool liquidation)
        public
        view
        virtual
        nonReentrantView
        returns (address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue)
    {
        VaultCache memory vaultCache = loadVault();

        validateController(account);
        validateOracle(vaultCache);
        collaterals = getCollaterals(account);
        collateralValues = new uint256[](collaterals.length);

        for (uint256 i; i < collaterals.length; ++i) {
            collateralValues[i] = getCollateralValue(
                vaultCache, account, collaterals[i], liquidation ? LTVType.LIQUIDATION : LTVType.BORROWING
            );
        }

        liabilityValue = getLiabilityValue(vaultCache, account, vaultStorage.users[account].getOwed());
    }

    /// @inheritdoc IRiskManager
    function disableController() public virtual nonReentrant {
        address account = EVCAuthenticate();

        if (!vaultStorage.users[account].getOwed().isZero()) revert E_OutstandingDebt();

        disableControllerInternal(account);
    }

    /// @inheritdoc IRiskManager
    /// @dev The function doesn't have a re-entrancy lock, because onlyEVCChecks provides equivalent behaviour. It ensures that the caller
    /// is the EVC, in 'checks in progress' state. In this state EVC will not accept any calls. Since all the functions which modify
    /// vault state use callThroughEVC modifier, they are effectively blocked while the function executes. There are non-view functions without
    /// callThroughEVC modifier (`flashLoan`, `disableCollateral`), but they don't change the vault's storage.
    function checkAccountStatus(address account, address[] calldata collaterals)
        public
        virtual
        reentrantOK
        onlyEVCChecks
        returns (bytes4 magicValue)
    {
        checkLiquidity(loadVault(), account, collaterals);

        magicValue = IEVCVault.checkAccountStatus.selector;
    }

    /// @inheritdoc IRiskManager
    /// @dev See comment about re-entrancy for `checkAccountStatus`
    function checkVaultStatus() public virtual reentrantOK onlyEVCChecks returns (bytes4 magicValue) {
        // Use the updating variant to make sure interest is accrued in storage before the interest rate update
        VaultCache memory vaultCache = updateVault();
        uint256 newInterestRate = computeInterestRate(vaultCache);

        logVaultStatus(vaultCache, newInterestRate);

        // We use the snapshot to check if the borrows or supply grew, and if so then we check the borrow and supply caps.
        // If snapshot is initialized, then caps are configured.
        // If caps are set in the middle of a batch, then snapshots represent the state of the vault at that time.
        if (vaultCache.snapshotInitialized) {
            vaultStorage.snapshotInitialized = vaultCache.snapshotInitialized = false;

            Assets snapshotCash = snapshot.cash;
            Assets snapshotBorrows = snapshot.borrows;

            uint256 prevBorrows = snapshotBorrows.toUint();
            uint256 borrows = vaultCache.totalBorrows.toAssetsUp().toUint();

            if (borrows > vaultCache.borrowCap && borrows > prevBorrows) revert E_BorrowCapExceeded();

            uint256 prevSupply = snapshotCash.toUint() + prevBorrows;
            uint256 supply = totalAssetsInternal(vaultCache);

            if (supply > vaultCache.supplyCap && supply > prevSupply) revert E_SupplyCapExceeded();

            snapshot.reset();
        }

        magicValue = IEVCVault.checkVaultStatus.selector;
    }
}

contract RiskManager is RiskManagerModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

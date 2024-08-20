// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../src/EVault/shared/Base.sol";
// Needed for checkLiquidityReturning:
import {LiquidityUtils} from "../../src/EVault/shared/LiquidityUtils.sol";

// This exists so that Base.LTVConfig and other type declarations 
// are available in CVL and can be used across specs for different modules.
// We need to split this into a concrete contract and an Abstract contract
// so that we can refer to Base.LTVConfig as a type in shared CVL functions
// while also making function definitions sharable among harnesses via
// AbstractBase. AbstractBaseHarness includes the shared function definitions.
abstract contract AbstractBaseHarness is Base, LiquidityUtils {

    function getLTVConfig(address collateral) external view returns (LTVConfig memory) {
        return vaultStorage.ltvLookup[collateral];
    }

    function vaultCacheOracleConfigured() external returns (bool) {
        return address(loadVault().oracle) != address(0);
    }

    function isAccountStatusCheckDeferredExt(address account) external view returns (bool) {
        return isAccountStatusCheckDeferred(account);
    }
    
    function getBalanceAndForwarderExt(address account) public returns (Shares, bool) {
        return vaultStorage.users[account].getBalanceAndBalanceForwarder();
    }

    function checkAccountMagicValue() public view returns (bytes4) {
        return IEVCVault.checkAccountStatus.selector;
    }

    function checkAccountMagicValueMemory() public view returns (bytes memory) {
        return abi.encodeWithSelector(IEVCVault.checkAccountStatus.selector);
    }

    function checkVaultMagicValueMemory() public view returns (bytes memory) {
        return abi.encodeWithSelector(IEVCVault.checkVaultStatus.selector);
    }

    function getUserInterestAccumulator(address account) public view returns (uint256) {
        return vaultStorage.users[account].interestAccumulator;
    }

    // This mirrors LiquidityUtils.checkLiquidity except that it returns
    // a bool rather than reverting.
    function checkLiquidityReturning(address account, address[] memory collaterals) public returns (bool) {
        VaultCache memory vaultCache = loadVault();
        
        Owed owed = vaultStorage.users[account].getOwed();
        if (owed.isZero()) return true;

        uint256 liabilityValue = getLiabilityValue(vaultCache, account, owed, false);

        uint256 collateralValue;
        for (uint256 i; i < collaterals.length; ++i) {
            collateralValue += getCollateralValue(vaultCache, account, collaterals[i], false);
            if (collateralValue > liabilityValue) return true;
        }

        return false;
    }


    //--------------------------------------------------------------------------
    // Controllers
    //--------------------------------------------------------------------------
    function vaultIsOnlyController(address account) external view returns (bool) {
        address[] memory controllers = IEVC(evc).getControllers(account);
        return controllers.length == 1 && controllers[0] == address(this);
    }

    function vaultIsController(address account) external view returns (bool) {
        return IEVC(evc).isControllerEnabled(account, address(this));
    }

    //--------------------------------------------------------------------------
    // Collaterals
    //--------------------------------------------------------------------------
    function getCollateralsExt(address account) public view returns (address[] memory) {
        return getCollaterals(account);
    }

    function isCollateralEnabledExt(address account, address market) external view returns (bool) {
        return isCollateralEnabled(account, market);
    }


    //--------------------------------------------------------------------------
    // Operation disable checks
    //--------------------------------------------------------------------------
    function isOperationDisabledExt(uint32 operation) public returns (bool) {
        VaultCache memory vaultCache = updateVault();
        return isOperationDisabled(vaultCache.hookedOps, operation);
    }

    function isDepositDisabled() public returns (bool) {
        return isOperationDisabledExt(OP_DEPOSIT);
    }

    function isMintDisabled() public returns (bool) {
        return isOperationDisabledExt(OP_MINT);
    }

    function isWithdrawDisabled() public returns (bool) {
        return isOperationDisabledExt(OP_WITHDRAW);
    }

    function isRedeemDisabled() public returns (bool) {
        return isOperationDisabledExt(OP_REDEEM);
    }

    function isSkimDisabled() public returns (bool) {
        return isOperationDisabledExt(OP_SKIM);
    }

    //--------------------------------------------------------------------------
    // VaultStorage Accessors:
    //--------------------------------------------------------------------------
    function storage_lastInterestAccumulatorUpdate() public view returns (uint48) {
        return vaultStorage.lastInterestAccumulatorUpdate;
    }
    function storage_cash() public view returns (Assets) {
        return vaultStorage.cash;
    }
    function storage_supplyCap() public view returns (uint256) {
        return vaultStorage.supplyCap.resolve();
    }
    function storage_borrowCap() public view returns (uint256) {
        return vaultStorage.borrowCap.resolve();
    }
    // reentrancyLocked seems not direclty used in loadVault
    function storage_hookedOps() public view returns (Flags) {
        return vaultStorage.hookedOps;
    }
    function storage_snapshotInitialized() public view returns (bool) {
        return vaultStorage.snapshotInitialized;
    }
    function storage_totalShares() public view returns (Shares) {
        return vaultStorage.totalShares;
    }
    function storage_totalBorrows() public view returns (Owed) {
        return vaultStorage.totalBorrows;
    }
    function storage_accumulatedFees() public view returns (Shares) {
        return vaultStorage.accumulatedFees;
    }
    function storage_interestAccumulator() public view returns (uint256) {
        return vaultStorage.interestAccumulator;
    }
    function storage_configFlags() public view returns (Flags) {
        return vaultStorage.configFlags;
    }


}
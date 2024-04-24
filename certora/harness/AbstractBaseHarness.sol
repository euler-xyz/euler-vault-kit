// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../src/EVault/shared/Base.sol";

// This exists so that Base.LTVConfig and other type declarations 
// are available in CVL and can be used across specs for different modules.
// We need to split this into a concrete contract and an Abstract contract
// so that we can refer to Base.LTVConfig as a type in shared CVL functions
// while also making function definitions sharable among harnesses via
// AbstractBase. AbstractBaseHarness includes the shared function definitions.
abstract contract AbstractBaseHarness is Base {

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


}
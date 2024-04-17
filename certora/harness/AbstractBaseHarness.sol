// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../src/EVault/shared/Base.sol";

// This mainly exists so that Base.LTVConfig and other type declarations 
// are available in CVL and can be used across specs for different modules.
// It also exports some functions common across the modules.

abstract contract AbstractBaseHarness is Base {
    function getCollateralsExt(address account) public view returns (address[] memory) {
        return getCollaterals(account);
    }

    function getLTVConfig(address collateral) external view returns (LTVConfig memory) {
        return vaultStorage.ltvLookup[collateral];
    }

    function vaultCacheOracleConfigured() external returns (bool) {
        return address(loadVault().oracle) != address(0);
    }

    function vaultIsOnlyController(address account) external view returns (bool) {
        address[] memory controllers = IEVC(evc).getControllers(account);
        return controllers.length == 1 && controllers[0] == address(this);
    }

    function vaultIsController(address account) external view returns (bool) {
        return IEVC(evc).isControllerEnabled(account, address(this));
    }
}
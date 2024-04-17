// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../../src/EVault/modules/RiskManager.sol";
import "../../src/EVault/shared/types/Types.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../src/interfaces/IPriceOracle.sol";
import {IERC20} from "../../src/EVault/IEVault.sol";
import {ERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../certora/harness/AbstractBaseHarness.sol";

contract RiskManagerHarness is RiskManager, AbstractBaseHarness {
    constructor(Integrations memory integrations) RiskManager(integrations) {}

    // function getCollateralsExt(address account) public view returns (address[] memory) {
    //     return getCollaterals(account);
    // }

    function vaultIsOnlyController(address account) external view returns (bool) {
        address[] memory controllers = IEVC(evc).getControllers(account);
        return controllers.length == 1 && controllers[0] == address(this);
    }

    function vaultCacheOracleConfigured() external returns (bool) {
        return address(loadVault().oracle) != address(0);
    }

    function getLTVConfig(address collateral) external view returns (LTVConfig memory) {
        return vaultStorage.ltvLookup[collateral];
    }


}
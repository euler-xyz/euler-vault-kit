// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
import "../../src/EVault/shared/types/Types.sol";
import "../../src/EVault/modules/Liquidation.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "../../src/interfaces/IPriceOracle.sol";
import {IERC20} from "../../src/EVault/IEVault.sol";
import {ERC20} from "../../lib/ethereum-vault-connector/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract LiquidationHarness is Liquidation {
    // VaultCache vaultCache_;
    // LiquidationCache liqCache_;

    constructor(Integrations memory integrations) Liquidation(integrations) {}

    function calculateLiquidityExternal(
        address account
    ) public view returns (uint256 collateralValue, uint256 liabilityValue) {
        return calculateLiquidity(loadVault(), account, getCollaterals(account), LTVType.LIQUIDATION);
    }

    function getLiquidityValue(address account, VaultCache memory vaultCache, address[] memory collaterals) public view returns (uint256 collateralValue) {
        (collateralValue, ) = calculateLiquidity(vaultCache, account, collaterals, LTVType.LIQUIDATION);
    }
    
    function getLiabilityValue(address account, VaultCache memory vaultCache, address[] memory collaterals) public view returns (uint256 liabilityValue) {
        (,liabilityValue) = calculateLiquidity(vaultCache, account, collaterals, LTVType.LIQUIDATION);
    }

    function loadVaultExt() public returns (VaultCache memory vaultCache) {
        return loadVault();
    }

    function initOperationExternal(uint32 operation, address accountToCheck)
        public 
        returns (VaultCache memory vaultCache, address account)
    {
        return initOperation(operation, accountToCheck);
    }

    function getCollateralsExt(address account) public view returns (address[] memory) {
        return getCollaterals(account);
    }

    function isRecognizedCollateralExt(address collateral) external view virtual returns (bool) {
        return isRecognizedCollateral(collateral);
    }

    function isCollateralEnabledExt(address account, address market) external view returns (bool) {
        return isCollateralEnabled(account, market);
    }

    function isAccountStatusCheckDeferredExt(address account) external view returns (bool) {
        return isAccountStatusCheckDeferred(account);
    }

    function vaultCacheOracleConfigured() external returns (bool) {
        return address(loadVault().oracle) != address(0);
    }

    function validateOracleExt(VaultCache memory vaultCache) external pure {
        validateOracle(vaultCache);
    }

    function getLiquidator() external returns (address liquidator) {
        (, liquidator) = initOperation(OP_LIQUIDATE, CHECKACCOUNT_CALLER);
    }

    function vaultIsOnlyController(address account) external view returns (bool) {
        address[] memory controllers = IEVC(evc).getControllers(account);
        return controllers.length == 1 && controllers[0] == address(this);
    }

    function vaultIsController(address account) external view returns (bool) {
        return IEVC(evc).isControllerEnabled(account, address(this));
    }

    function calculateLiquidationExt(
        VaultCache memory vaultCache,
        address liquidator,
        address violator,
        address collateral,
        uint256 desiredRepay
    ) external view returns (LiquidationCache memory liqCache) {
        return calculateLiquidation(vaultCache, liquidator, violator, collateral, desiredRepay);
    }

    function getCurrentOwedExt(VaultCache memory vaultCache, address violator) external view returns (Assets) {
        return getCurrentOwed(vaultCache, violator).toAssetsUp();
    }


}
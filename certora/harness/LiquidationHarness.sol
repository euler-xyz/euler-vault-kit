// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
import "../../src/EVault/shared/types/Types.sol";
import "../../src/EVault/modules/Liquidation.sol";


contract LiquidationHarness is Liquidation {
    constructor(Integrations memory integrations) Liquidation(integrations) {}

    function calculateLiquidityExternal(
        address account
    ) public view returns (uint256 collateralValue, uint256 liabilityValue) {
        return calculateLiquidity(loadMarket(), account, getCollaterals(account), LTVType.LIQUIDATION);
    }

    function getLiquidityValue(address account, MarketCache memory marketCache, address[] memory collaterals) public view returns (uint256 collateralValue) {
        (collateralValue, ) = calculateLiquidity(marketCache, account, collaterals, LTVType.LIQUIDATION);
    }
    
    function getLiabilityValue(address account, MarketCache memory marketCache, address[] memory collaterals) public view returns (uint256 liabilityValue) {
        (,liabilityValue) = calculateLiquidity(marketCache, account, collaterals, LTVType.LIQUIDATION);
    }

    function loadMarketExt() public returns (MarketCache memory marketCache) {
        return loadMarket();
    }

    function initOperationExternal(uint32 operation, address accountToCheck)
        public 
        returns (MarketCache memory marketCache, address account)
    {
        return initOperation(operation, accountToCheck);
    }

    function getCollateralsExt(address account) public view returns (address[] memory) {
        return getCollaterals(account);
    }

    function getNumCollaterals(address account) public view returns (uint256) {
        return getCollaterals(account).length;
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


}
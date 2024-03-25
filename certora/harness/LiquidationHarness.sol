// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
import "../../src/EVault/shared/types/Types.sol";
import "../../src/EVault/modules/Liquidation.sol";


contract LiquidationHarness is Liquidation {
    constructor(Integrations memory integrations) Liquidation(integrations) {}

    function calculateLiquidityExternal(
        address account
    ) public view returns (uint256 collateralValue, uint256 liabilityValue) {
        MarketCache memory marketCache; // uninitialized
        return calculateLiquidity(marketCache, account, getCollaterals(account), LTVType.LIQUIDATION);
    }

    function initOperationExternal(uint32 operation, address accountToCheck)
        public 
        returns (MarketCache memory marketCache, address account)
    {
        return initOperation(operation, accountToCheck);
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
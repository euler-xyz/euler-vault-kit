// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
import "../../src/EVault/shared/types/Types.sol";
import "../../src/EVault/modules/Liquidation.sol";


contract LiquidationHarness is Liquidation {
    constructor(Integrations memory integrations) Liquidation(integrations) {}

    // function calculateLiquidationExternal(
    //     MarketCache memory marketCache,
    //     address liquidator,
    //     address violator,
    //     address collateral,
    //     uint256 desiredRepay
    // ) public view returns (LiquidationCache memory liqCache) {
    //     return  calculateLiquidation(
    //         marketCache,
    //         liquidator,
    //         violator,
    //         collateral,
    //         desiredRepay);
    // }
}
// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseModule} from "../shared/BaseModule.sol";
import {ILiquidation} from "../IEVault.sol";

abstract contract LiquidationModule is BaseModule, ILiquidation {

}

contract Liquidation is LiquidationModule {
    constructor(address factory, address cvc) BaseModule(factory, cvc) {}
}
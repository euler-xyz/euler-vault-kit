// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseModule} from "../shared/BaseModule.sol";
import {IAdmin} from "../IEVault.sol";

abstract contract AdminModule is BaseModule, IAdmin {

}

contract Admin is AdminModule {
    constructor(address factory, address cvc) BaseModule(factory, cvc) {}
}
// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "../shared/Base.sol";
import {IAdmin} from "../IEVault.sol";

import "../shared/types/Types.sol";

abstract contract AdminModule is IAdmin, Base {

}

contract Admin is AdminModule {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}
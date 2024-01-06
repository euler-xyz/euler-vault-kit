// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IFees} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

abstract contract FeesModule is IFees {}

contract FeesInstance is FeesModule, Base {
    constructor(address evc) Base(evc) {}
}

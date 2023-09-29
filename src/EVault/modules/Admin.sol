// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { IAdmin } from "../IEVault.sol";

abstract contract AdminModule is IAdmin {

}

contract Admin is AdminModule {}
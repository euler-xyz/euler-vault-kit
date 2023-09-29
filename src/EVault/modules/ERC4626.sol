// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { IERC4626 } from "../IEVault.sol";

abstract contract ERC4626Module is IERC4626 {

}

contract ERC4626 is ERC4626Module {}
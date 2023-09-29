// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import { IERC20 } from "../IEVault.sol";

abstract contract ERC20Module is IERC20 {
    function name() external view virtual returns(string memory) {
        return "EVault";
    }
}

contract ERC20 is ERC20Module {}
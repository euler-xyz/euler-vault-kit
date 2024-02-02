// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";

library ProxyUtils {
    function metadata() internal pure returns (IERC20 marketAsset) {
        assembly {
            marketAsset := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}

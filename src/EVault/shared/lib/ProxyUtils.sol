// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {IPriceOracle} from "../../../interfaces/IPriceOracle.sol";

import "../Constants.sol";

/// @title ProxyUtils Library
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice The library provides a helper function for working with proxy meta data
library ProxyUtils {
    function metadata() internal pure returns (IERC20 asset, IPriceOracle oracle, address unitOfAccount) {
        assembly {
            asset := shr(96, calldataload(sub(calldatasize(), 60)))
            oracle := shr(96, calldataload(sub(calldatasize(), 40)))
            unitOfAccount := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    function useViewCaller() internal pure returns (address viewCaller) {
        assembly {
            viewCaller := shr(96, calldataload(sub(calldatasize(), add(PROXY_METADATA_LENGTH, 20))))
        }
    }
}

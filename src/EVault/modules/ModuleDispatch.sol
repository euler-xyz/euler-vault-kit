// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Errors} from "../shared/Errors.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

abstract contract ModuleDispatch is Errors {
    // Modifier proxies the function call to a module and low-level returns the result
    modifier use(address module) {
        _;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // Delegate call can't be used in a view function. To work around this limitation,
    // static call `this.viewDelegate()` function, which in turn will delegate the payload to a module.
    modifier useView(address module) {
        _;
        assembly {
            // Construct optimized custom call data:
            // [selector 4B][module address 32B][msg.data with stripped proxy metadata]
            // Proxy metadata will be appended back by the staticcall
            mstore(0, 0x1fe8b95300000000000000000000000000000000000000000000000000000000)
            mstore(4, module)
            calldatacopy(36, 0, calldatasize())
            // insize: calldatasize + 36 (sig and address) - 40 (strip proxy metadata)
            let result := staticcall(gas(), address(), 0, sub(calldatasize(), 4), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function viewDelegate() external {
        if (msg.sender != address(this)) revert E_Unauthorized();

        assembly {
            let module := calldataload(4)
            let size := sub(calldatasize(), 36)
            calldatacopy(0, 36, size)
            let result := delegatecall(gas(), module, 0, size, 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

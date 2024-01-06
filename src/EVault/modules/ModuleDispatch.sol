// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "../shared/Base.sol";
import "../shared/Constants.sol";

abstract contract ModuleDispatch is Base {
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
            // Construct optimized custom call data for `this.viewDelegate()`
            // [selector 4B][module address 32B][calldata with stripped proxy metadata]
            // Proxy metadata will be appended back by the proxy on staticcall
            mstore(0, 0x1fe8b95300000000000000000000000000000000000000000000000000000000)
            mstore(4, module)
            calldatacopy(36, 0, calldatasize())
            // insize: calldatasize + 36 (signature and address) - proxy metadata size (assuming PROXY_METADATA_LENGTH = 40)
            let result := staticcall(gas(), address(), 0, sub(calldatasize(), 4), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    modifier callThroughEVC() {
        if (msg.sender == address(evc)) {
            _;
        } else {
            address _evc = address(evc);
            assembly {
                mstore(0, 0x1f8b521500000000000000000000000000000000000000000000000000000000) // EVC.call signature
                mstore(4, address()) // callback 1st argument - address(this)
                mstore(36, caller()) // callback 2nd argument - msg.sender
                mstore(68, callvalue()) // callback 3rd argument - msg.value
                mstore(100, 128) // callback 4th argument - msg.data, offset to the start of encoding - 128 bytes
                mstore(132, sub(calldatasize(), PROXY_METADATA_LENGTH)) // msg.data length without proxy metadata
                calldatacopy(164, 0, sub(calldatasize(), PROXY_METADATA_LENGTH)) // original calldata
                let result := call(gas(), _evc, callvalue(), 0, add(124, calldatasize()), 0, 0)

                returndatacopy(0, 0, returndatasize())
                switch result
                case 0 { revert(0, returndatasize()) }
                default { return(64, sub(returndatasize(), 64)) } // strip bytes encoding from call return
            }
        }
    }

    function viewDelegate() external {
        if (msg.sender != address(this)) revert E_Unauthorized();

        assembly {
            let size := sub(calldatasize(), 36)
            calldatacopy(0, 36, size)
            let result := delegatecall(gas(), calldataload(4), 0, size, 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

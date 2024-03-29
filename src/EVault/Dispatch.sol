// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./shared/Base.sol";

import {TokenModule} from "./modules/Token.sol";
import {VaultModule} from "./modules/Vault.sol";
import {BorrowingModule} from "./modules/Borrowing.sol";
import {LiquidationModule} from "./modules/Liquidation.sol";
import {InitializeModule} from "./modules/Initialize.sol";
import {BalanceForwarderModule} from "./modules/BalanceForwarder.sol";
import {GovernanceModule} from "./modules/Governance.sol";
import {RiskManagerModule} from "./modules/RiskManager.sol";

import "./shared/Constants.sol";

abstract contract Dispatch is
    Base,
    InitializeModule,
    TokenModule,
    VaultModule,
    BorrowingModule,
    LiquidationModule,
    RiskManagerModule,
    BalanceForwarderModule,
    GovernanceModule
{
    address public immutable MODULE_INITIALIZE;
    address public immutable MODULE_TOKEN;
    address public immutable MODULE_VAULT;
    address public immutable MODULE_BORROWING;
    address public immutable MODULE_LIQUIDATION;
    address public immutable MODULE_RISKMANAGER;
    address public immutable MODULE_BALANCE_FORWARDER;
    address public immutable MODULE_GOVERNANCE;

    struct DeployedModules {
        address initialize;
        address token;
        address vault;
        address borrowing;
        address liquidation;
        address riskManager;
        address balanceForwarder;
        address governance;
    }

    constructor(Integrations memory integrations, DeployedModules memory modules) Base(integrations) {
        MODULE_INITIALIZE = modules.initialize;
        MODULE_TOKEN = modules.token;
        MODULE_VAULT = modules.vault;
        MODULE_BORROWING = modules.borrowing;
        MODULE_LIQUIDATION = modules.liquidation;
        MODULE_RISKMANAGER = modules.riskManager;
        MODULE_BALANCE_FORWARDER = modules.balanceForwarder;
        MODULE_GOVERNANCE = modules.governance;
    }

    // Modifier proxies the function call to a module and low-level returns the result
    modifier use(address module) {
        _; // when using the modifier, it is assumed the function body is empty and no code will run before delegating to module.
        delegateToModule(module);
    }

    // Delegate call can't be used in a view function. To work around this limitation,
    // static call `this.viewDelegate()` function, which in turn will delegate the payload to a module.
    modifier useView(address module) {
        _; // when using the modifier, it is assumed the function body is empty and no code will run before delegating to module.
        delegateToModuleView(module);
    }

    modifier callThroughEVC() {
        if (msg.sender == address(evc)) {
            _;
        } else {
            callThroughEVCInternal();
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

    function delegateToModule(address module) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function delegateToModuleView(address module) private view {
        assembly {
            // Construct optimized custom call data for `this.viewDelegate()`
            // [selector 4B][module address 32B][calldata with stripped proxy metadata]
            // Proxy metadata will be appended back by the proxy on staticcall
            mstore(0, 0x1fe8b95300000000000000000000000000000000000000000000000000000000)
            mstore(4, module)
            calldatacopy(36, 0, calldatasize())
            // insize: calldatasize + 36 (signature and address) - proxy metadata size
            let result := staticcall(gas(), address(), 0, sub(add(calldatasize(), 36), PROXY_METADATA_LENGTH), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // Modifier ensures, that the body of the function is always executed from the EVC call.
    // It is accomplished by intercepting calls incoming directly to the vault and passing them
    // to the EVC.call function. EVC calls the vault back with original calldata. As a result, the account
    // and vault status checks are always executed in the checks deferral frame, at the end of the call,
    // outside of the vault's re-entrancy protections.
    // The modifier is applied to all functions which schedule account or vault status checks.
    function callThroughEVCInternal() private {
        address _evc = address(evc);
        assembly {
            let mainCalldataLength := sub(calldatasize(), PROXY_METADATA_LENGTH)

            mstore(0, 0x1f8b521500000000000000000000000000000000000000000000000000000000) // EVC.call signature
            mstore(4, address()) // EVC.call 1st argument - address(this)
            mstore(36, caller()) // EVC.call 2nd argument - msg.sender
            mstore(68, callvalue()) // EVC.call 3rd argument - msg.value
            mstore(100, 128) // EVC.call 4th argument - msg.data, offset to the start of encoding - 128 bytes
            mstore(132, mainCalldataLength) // msg.data length without proxy metadata
            calldatacopy(164, 0, mainCalldataLength) // original calldata
            let result := call(gas(), _evc, callvalue(), 0, add(164, mainCalldataLength), 0, 0)

            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(64, sub(returndatasize(), 64)) } // strip bytes encoding from call return
        }
    }
}

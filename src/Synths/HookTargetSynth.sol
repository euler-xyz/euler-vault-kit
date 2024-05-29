// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IHookTarget} from "../interfaces/IHookTarget.sol";
import {IEVault} from "../EVault/IEVault.sol";

/// @title HookTargetSynth
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice HookTargetSynth is designed to block unnecessary operations and enforce deposits only by the asset contract.
contract HookTargetSynth is IHookTarget {
    error E_OnlyAssetCanDeposit();
    error E_OperationDisabled();

    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    // deposit is only allowed for the asset itself
    function deposit(uint256, address) external view {
        if (IEVault(msg.sender).asset() != caller()) revert E_OnlyAssetCanDeposit();
    }

    // all the other hooked operations are disabled
    fallback() external {
        revert E_OperationDisabled();
    }

    function caller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}

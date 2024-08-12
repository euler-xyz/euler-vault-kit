// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {RevertBytes} from "./RevertBytes.sol";
import {IPermit2} from "../../../interfaces/IPermit2.sol";

/// @title SafeERC20Lib Library
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice The library provides helpers for ERC20 transfers, including Permit2 support
library SafeERC20Lib {
    error E_TransferFromFailed(bytes errorPermit2, bytes errorTransferFrom);

    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in
    // `initialize`.
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value)
        internal
        returns (bool, bytes memory)
    {
        (bool success, bytes memory data) = address(token).call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));

        return isEmptyOrTrueReturn(success, data) ? (true, bytes("")) : (false, data);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value, address permit2) internal {
        bool success;
        bytes memory permit2Data;
        bytes memory transferData;

        if (permit2 != address(0) && value <= type(uint160).max) {
            // it's safe to down-cast value to uint160
            (success, permit2Data) =
                permit2.call(abi.encodeCall(IPermit2.transferFrom, (from, to, uint160(value), address(token))));
        }

        if (!success) {
            (success, transferData) = trySafeTransferFrom(token, from, to, value);
        }

        if (!success) revert E_TransferFromFailed(permit2Data, transferData);
    }

    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in
    // `initialize`.
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeCall(IERC20.transfer, (to, value)));
        if (!isEmptyOrTrueReturn(success, data)) RevertBytes.revertBytes(data);
    }

    function isEmptyOrTrueReturn(bool callSuccess, bytes memory data) private pure returns (bool) {
        return callSuccess && (data.length == 0 || (data.length >= 32 && abi.decode(data, (bool))));
    }
}

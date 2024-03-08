// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {RevertBytes} from "./RevertBytes.sol";

interface IPermit2 {
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

library SafeERC20Lib {
    error TransferFromFailed(bytes errorTransferFrom, bytes errorPermit2);
    error Permit2AmountOverflow();

    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in `initialize`.
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));

        return (!success || (data.length != 0 && !abi.decode(data, (bool))))
            ? (false, data)
            : (true, bytes(""));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value, address permit2) internal {
        (bool success, bytes memory tryData) = trySafeTransferFrom(token, from, to, value);
        if (!success) {
            if (value > type(uint160).max) revert TransferFromFailed(tryData, abi.encodeWithSignature("Permit2AmountOverflow()"));

            bytes memory data;
            (success, data) = permit2.call(abi.encodeCall(IPermit2.transferFrom, (from, to, uint160(value), address(token))));
            if (success) revert TransferFromFailed(tryData, data);
        }

    }

    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in `initialize`.
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) RevertBytes.revertBytes(data);
    }
}

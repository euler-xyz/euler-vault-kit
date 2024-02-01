// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./ISwapHandler.sol";
// import "../Interfaces.sol";
// import "../EVault/shared/lib/Utils.sol";
import {IERC20} from "../EVault/IEVault.sol";
import {SafeERC20Lib} from "../EVault/shared/lib/SafeERC20Lib.sol";

/// @notice Base contract for swap handlers
abstract contract SwapHandlerBase is ISwapHandler {
    using SafeERC20Lib for IERC20;

    function trySafeApprove(address token, address to, uint256 value) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.approve, (to, value)));
        return (success && (data.length == 0 || abi.decode(data, (bool))), data);
    }

    function safeApproveWithRetry(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = trySafeApprove(token, to, value);

        // some tokens, like USDT, require the allowance to be set to 0 first
        if (!success) {
            (success,) = trySafeApprove(token, to, 0);
            if (success) {
                (success,) = trySafeApprove(token, to, value);
            }
        }

        if (!success) revertBytes(data);
    }

    function transferBack(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) IERC20(token).safeTransfer(msg.sender, balance);
    }

    function setMaxAllowance(address token, uint256 minAllowance, address spender) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < minAllowance) safeApproveWithRetry(token, spender, type(uint256).max);
    }

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert("SwapHandlerBase: empty error");
    }
}

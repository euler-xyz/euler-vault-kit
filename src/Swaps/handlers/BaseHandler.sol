// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../ISwapper.sol";
import {IERC20} from "../../EVault/IEVault.sol";
import {SafeERC20Lib} from "../../EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

abstract contract BaseHandler is ISwapper {
    uint256 internal constant SWAPMODE__EXACT_IN = 0;
    uint256 internal constant SWAPMODE__EXACT_OUT = 1;
    uint256 internal constant SWAPMODE__TARGET_DEBT = 2;

    error SwapHandler_UnsupportedMode();

    /// Calculate how much needs to be swapped
    function targetDebtToAmountOut(address account, address vaultOut, uint256 targetDebt) internal view returns (uint256) {
        // TODO

        return targetDebt;
    }

    function transferBack(address token) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) SafeERC20Lib.safeTransfer(IERC20(token), msg.sender, balance);
    }

    function setMaxAllowance(address token, uint256 minAllowance, address spender) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < minAllowance) safeApproveWithRetry(token, spender, type(uint256).max);
    }

    function trySafeApprove(address token, address to, uint256 value) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
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

        if (!success) RevertBytes.revertBytes(data);
    }
}

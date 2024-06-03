// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../ISwapper.sol";
import {IEVault, IERC20} from "../../EVault/IEVault.sol";
import {SafeERC20Lib} from "../../EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

abstract contract BaseHandler is ISwapper {
    uint256 internal constant SWAPMODE_EXACT_IN = 0;
    uint256 internal constant SWAPMODE_EXACT_OUT = 1;
    uint256 internal constant SWAPMODE_TARGET_DEBT = 2;

    error SwapHandler_UnsupportedMode();
    error SwapHandler_TargetDebt();
    error SwapHandler_TargetDebtBalance();

    function resolveAmountOut(SwapParams memory params) internal view returns (uint256 amountOut) {
        if (params.mode != SWAPMODE_TARGET_DEBT) return params.amountOut;

        // params.amountOut is the target debt
        uint256 debt = IEVault(params.receiver).debtOf(params.account);
        if (params.amountOut > debt) revert SwapHandler_TargetDebt();

        amountOut = debt - params.amountOut;

        // TODO - return unused? leave for sweep?
        uint256 balance = IERC20(params.tokenOut).balanceOf(address(this));
        if (balance > amountOut) revert SwapHandler_TargetDebtBalance();

        amountOut -= balance;
    }

    function setMaxAllowance(address token, address spender) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < balance) safeApproveWithRetry(token, spender, type(uint256).max);
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

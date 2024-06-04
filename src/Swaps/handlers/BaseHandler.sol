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
    uint256 internal constant SWAPMODE_MAX_VALUE = 3;

    error Swapper_UnsupportedMode();
    error Swapper_TargetDebt();
    error Swapper_TargetDebtBalance();

    // update params in place
    function resolveParams(SwapParams memory params) internal view {
        if (params.mode == SWAPMODE_EXACT_IN) return;

        uint256 amountOut = params.amountOut;
        uint256 balanceOut = IERC20(params.tokenOut).balanceOf(address(this));

        // for combined exact output swaps, which accumulate the output in the swapper, check how much is already available
        if (params.mode == SWAPMODE_EXACT_OUT && params.receiver == address(this)) {
            amountOut = balanceOut >= amountOut ? 0 : amountOut - balanceOut;
        }

        if (params.mode == SWAPMODE_TARGET_DEBT) {
            // amountOut is the target debt
            uint256 debt = IEVault(params.receiver).debtOf(params.account);

            if (amountOut > debt) revert Swapper_TargetDebt();

            amountOut = debt - amountOut;

            // TODO - return unused? leave for sweep?

            if (balanceOut > amountOut) revert Swapper_TargetDebtBalance();

            amountOut -= balanceOut;
            params.receiver = address(this); // collect output in the swapper for repay
        }

        params.amountOut = amountOut;
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

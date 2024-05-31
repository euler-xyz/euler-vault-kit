// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {ISwapRouterV3} from "../vendor/ISwapRouterV3.sol";

abstract contract UniswapV3Handler is BaseHandler {
    address public immutable uniSwapRouterV3;

    error UniswapV3Handler_InvalidPath();

    constructor(address _uniSwapRouterV3) {
        uniSwapRouterV3 = _uniSwapRouterV3;
    }

    function swap(SwapParams calldata params) public virtual override {
        if (params.mode == SWAPMODE__EXACT_IN) revert SwapHandler_UnsupportedMode();
        if (params.data.length < 43 || (params.data.length - 20) % 23 != 0) revert UniswapV3Handler_InvalidPath();

        setMaxAllowance(params.tokenIn, params.amountIn, uniSwapRouterV3);

        uint256 amountOut = params.mode == SWAPMODE__TARGET_DEBT
            ? targetDebtToAmountOut(params.account, params.amountOut)
            : params.amountOut;

        ISwapRouterV3(uniSwapRouterV3).exactOutput(
            ISwapRouterV3.ExactOutputParams({
                path: params.data,
                recipient: params.receiver,
                amountOut: amountOut,
                amountInMaximum: type(uint256).max,
                deadline: block.timestamp
            })
        );
    }
}

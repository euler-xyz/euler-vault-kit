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

    function swap(SwapParams memory params) public virtual override {
        if (params.mode == SWAPMODE_EXACT_IN) revert Swapper_UnsupportedMode();
        if (params.data.length < 43 || (params.data.length - 20) % 23 != 0) revert UniswapV3Handler_InvalidPath();

        setMaxAllowance(params.tokenIn, uniSwapRouterV3);
        // update params according to the mode and current state
        resolveParams(params);

        if (params.amountOut > 0) {
            ISwapRouterV3(uniSwapRouterV3).exactOutput(
                ISwapRouterV3.ExactOutputParams({
                    path: params.data,
                    recipient: params.receiver,
                    amountOut: params.amountOut,
                    amountInMaximum: type(uint256).max,
                    deadline: block.timestamp
                })
            );
        }
    }
}

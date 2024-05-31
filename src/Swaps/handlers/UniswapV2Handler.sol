// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {ISwapRouterV2} from "../vendor/ISwapRouterV2.sol";

abstract contract UniswapV2Handler is BaseHandler {
    address public immutable uniSwapRouterV2;

    error UniswapV2Handler_InvalidPath();

    constructor(address _uniSwapRouterV2) {
        uniSwapRouterV2 = _uniSwapRouterV2;
    }

    function swap(SwapParams memory params) public virtual override {
        if (params.mode == SWAPMODE_EXACT_IN) revert SwapHandler_UnsupportedMode();
        if (params.data.length < 64 || params.data.length % 32 != 0) revert UniswapV2Handler_InvalidPath();

        setMaxAllowance(params.tokenIn, params.amountIn, uniSwapRouterV2);

        uint256 amountOut = resolveAmountOut(params);

        if (amountOut > 0) {
            ISwapRouterV2(uniSwapRouterV2).swapTokensForExactTokens({
                amountOut: amountOut,
                amountInMax: type(uint256).max,
                path: abi.decode(params.data, (address[])),
                to: params.receiver,
                deadline: block.timestamp
            });
        }
    }
}

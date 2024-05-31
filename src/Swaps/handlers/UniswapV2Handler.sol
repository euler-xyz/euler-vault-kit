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

    function swap(SwapParams calldata params) public virtual override {
        if (params.mode == SWAPMODE__EXACT_IN) revert SwapHandler_UnsupportedMode();
        if (params.data.length < 64 || params.data.length % 32 != 0) revert UniswapV2Handler_InvalidPath();

        setMaxAllowance(params.tokenIn, params.amountIn, uniSwapRouterV2);

        uint256 amountOut = params.mode == SWAPMODE__TARGET_DEBT
            ? targetDebtToAmountOut(params.account, params.amountOut)
            : params.amountOut;

        ISwapRouterV2(uniSwapRouterV2).swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: type(uint256).max,
            path: abi.decode(params.data, (address[])),
            to: params.receiver,
            deadline: block.timestamp
        });
    }
}

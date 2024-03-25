// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./SwapHandlerBase.sol";
import "../../vendor/ISwapRouterV3.sol";

/// @notice Swap handler executing trades on UniswapV3 through SwapRouter
contract SwapHandlerUniswapV3 is SwapHandlerBase {
    address immutable public uniSwapRouterV3;

    constructor(address uniSwapRouterV3_) {
        uniSwapRouterV3 = uniSwapRouterV3_;
    }

    function executeSwap(SwapParams calldata params) override external {
        require(params.mode <= 1, "SwapHandlerUniswapV3: invalid mode");

        setMaxAllowance(params.underlyingIn, params.amountIn, uniSwapRouterV3);

        // The payload in SwapParams has double use. For single pool swaps, the price limit and a pool fee are abi-encoded as 2 uints, where bytes length is 64.
        // For multi-pool swaps, the payload represents a swap path. A valid path is a packed encoding of tokenIn, pool fee and tokenOut.
        // The valid path lengths are therefore: 20 + n*(3 + 20), where n >= 1, and no valid path can be 64 bytes long.
        if (params.payload.length == 64) {
            (uint sqrtPriceLimitX96, uint fee) = abi.decode(params.payload, (uint, uint));
            if (params.mode == 0)
                exactInputSingle(params, sqrtPriceLimitX96, fee);
            else
                exactOutputSingle(params, sqrtPriceLimitX96, fee);
        } else {
            if (params.mode == 0)
                exactInput(params, params.payload);
            else
                exactOutput(params, params.payload);
        }

        if (params.mode == 1) transferBack(params.underlyingIn);
    }

    function exactInputSingle(SwapParams memory params, uint sqrtPriceLimitX96, uint fee) private {
        ISwapRouterV3(uniSwapRouterV3).exactInputSingle(
            ISwapRouterV3.ExactInputSingleParams({
                tokenIn: params.underlyingIn,
                tokenOut: params.underlyingOut,
                fee: uint24(fee),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: params.amountIn,
                amountOutMinimum: params.amountOut,
                sqrtPriceLimitX96: uint160(sqrtPriceLimitX96)
            })
        );
    }

    function exactInput(SwapParams memory params, bytes memory path) private {
        ISwapRouterV3(uniSwapRouterV3).exactInput(
            ISwapRouterV3.ExactInputParams({
                path: path,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: params.amountIn,
                amountOutMinimum: params.amountOut
            })
        );
    }

    function exactOutputSingle(SwapParams memory params, uint sqrtPriceLimitX96, uint fee) private {
        ISwapRouterV3(uniSwapRouterV3).exactOutputSingle(
            ISwapRouterV3.ExactOutputSingleParams({
                tokenIn: params.underlyingIn,
                tokenOut: params.underlyingOut,
                fee: uint24(fee),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: params.amountOut,
                amountInMaximum: params.amountIn,
                sqrtPriceLimitX96: uint160(sqrtPriceLimitX96)
            })
        );
    }

    function exactOutput(SwapParams memory params, bytes memory path) private {
        ISwapRouterV3(uniSwapRouterV3).exactOutput(
            ISwapRouterV3.ExactOutputParams({
                path: path,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: params.amountOut,
                amountInMaximum: params.amountIn
            })
        );
    }
}

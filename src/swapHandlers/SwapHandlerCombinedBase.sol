// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./SwapHandlerBase.sol";
import "../vendor/ISwapRouterV3.sol";
import "../vendor/ISwapRouterV2.sol";

/// @notice Base contract for swap handlers which execute a secondary swap on Uniswap V2 or V3 for exact output
abstract contract SwapHandlerCombinedBase is SwapHandlerBase {
    address public immutable uniSwapRouterV2;
    address public immutable uniSwapRouterV3;

    constructor(address uniSwapRouterV2_, address uniSwapRouterV3_) {
        uniSwapRouterV2 = uniSwapRouterV2_;
        uniSwapRouterV3 = uniSwapRouterV3_;
    }

    function executeSwap(SwapParams memory params) external override {
        require(params.mode <= 1, "SwapHandlerCombinedBase: invalid mode");

        if (params.mode == 0) {
            swapPrimary(params);
        } else {
            // For exact output expect a payload for the primary swap provider and a path to swap the remainder on Uni2 or Uni3
            bytes memory path;
            (params.payload, path) = abi.decode(params.payload, (bytes, bytes));

            uint256 primaryAmountOut = swapPrimary(params);

            if (primaryAmountOut < params.amountOut) {
                // The path param is reused for UniV2 and UniV3 swaps. The protocol to use is determined by the path length.
                // The length of valid UniV2 paths is given as n * 20, for n > 1, and the shortes path is 40 bytes.
                // The length of valid UniV3 paths is given as 20 + n * 23 for n > 0, because of an additional 3 bytes for the pool fee.
                // The max path length must be lower than the first path length which is valid for both protocols (and is therefore ambiguous)
                // This value is at 20 UniV3 hops, which corresponds to 24 UniV2 hops.
                require(
                    path.length >= 40 && path.length < 20 + (20 * 23), "SwapHandlerPayloadBase: secondary path format"
                );

                uint256 remainder;
                unchecked {
                    remainder = params.amountOut - primaryAmountOut;
                }

                swapExactOutDirect(params, remainder, path);
            }
        }

        transferBack(params.underlyingIn);
    }

    function swapPrimary(SwapParams memory params) internal virtual returns (uint256 amountOut);

    function swapExactOutDirect(SwapParams memory params, uint256 amountOut, bytes memory path) private {
        (bool isUniV2, address[] memory uniV2Path) = detectAndDecodeUniV2Path(path);

        if (isUniV2) {
            setMaxAllowance(params.underlyingIn, params.amountIn, uniSwapRouterV2);

            ISwapRouterV2(uniSwapRouterV2).swapTokensForExactTokens(
                amountOut, type(uint256).max, uniV2Path, msg.sender, block.timestamp
            );
        } else {
            setMaxAllowance(params.underlyingIn, params.amountIn, uniSwapRouterV3);

            ISwapRouterV3(uniSwapRouterV3).exactOutput(
                ISwapRouterV3.ExactOutputParams({
                    path: path,
                    recipient: msg.sender,
                    amountOut: amountOut,
                    amountInMaximum: type(uint256).max,
                    deadline: block.timestamp
                })
            );
        }
    }

    function detectAndDecodeUniV2Path(bytes memory path) private pure returns (bool, address[] memory) {
        bool isUniV2 = path.length % 20 == 0;
        address[] memory addressPath;

        if (isUniV2) {
            uint256 addressPathSize = path.length / 20;
            addressPath = new address[](addressPathSize);

            unchecked {
                for (uint256 i = 0; i < addressPathSize; ++i) {
                    addressPath[i] = toAddress(path, i * 20);
                }
            }
        }

        return (isUniV2, addressPath);
    }

    function toAddress(bytes memory data, uint256 start) private pure returns (address result) {
        // assuming data length is already validated
        assembly {
            // borrowed from BytesLib https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
            result := div(mload(add(add(data, 0x20), start)), 0x1000000000000000000000000)
        }
    }
}

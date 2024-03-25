// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./SwapHandlerCombinedBase.sol";

/// @notice Swap handler executing trades on 1Inch
contract SwapHandler1Inch is SwapHandlerCombinedBase {
    address immutable public oneInchAggregator;

    constructor(address oneInchAggregator_, address uniSwapRouterV2, address uniSwapRouterV3) SwapHandlerCombinedBase(uniSwapRouterV2, uniSwapRouterV3) {
        oneInchAggregator = oneInchAggregator_;
    }

    function swapPrimary(SwapParams memory params) override internal returns (uint amountOut) {
        setMaxAllowance(params.underlyingIn, params.amountIn, oneInchAggregator);

        (bool success, bytes memory result) = oneInchAggregator.call(params.payload);
        if (!success) revertBytes(result);

        // return amount out reported by 1Inch. It might not be exact for fee-on-transfer or rebasing tokens.
        amountOut = abi.decode(result, (uint));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

// import "../ISwapper.sol";
// import {IERC20} from "../../EVault/IEVault.sol";
// import {SafeERC20Lib} from "../../EVault/shared/lib/SafeERC20Lib.sol";
// import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

import {OneInchHandler} from "./handlers/OneInchHandler.sol";
import {UniswapV2Handler} from "./handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "./handlers/UniswapV3Handler.sol";

contract Swapper is OneInchHandler, UniswapV2Handler, UniswapV3Handler {
    uint256 internal constant HANDLER_ONE_INCH = 0;
    uint256 internal constant HANDLER_UNISWAP_V2 = 1;
    uint256 internal constant HANDLER_UNISWAP_V3 = 2;

    error Swapper_UnsupportedHandler();

    constructor(address oneInchAggregator, address uniswapRouterV2, address uniswapRouterV3)
        OneInchHandler(oneInchAggregator)
        UniswapV2Handler(uniswapRouterV2)
        UniswapV3Handler(uniswapRouterV3)
    {}

    function swap(SwapParams calldata params) public override (OneInchHandler, UniswapV2Handler, UniswapV3Handler) {
        if (params.handler == HANDLER_ONE_INCH) {
            OneInchHandler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V2) {
            UniswapV2Handler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V3) {
            UniswapV3Handler.swap(params);
        } else {
            revert Swapper_UnsupportedHandler();
        }

        // TODO return unused
    }

    function repay() public {}

    function sweep() public {}

    function multicall() external {}
}

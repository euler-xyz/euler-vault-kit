// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

abstract contract OneInchHandler is BaseHandler {
    address public immutable oneInchAggregator;

    constructor(address _oneInchAggregator) {
        oneInchAggregator = _oneInchAggregator;
    }

    function swap(SwapParams calldata params) public virtual override {
        if (params.mode != SWAPMODE__EXACT_IN) revert SwapHandler_UnsupportedMode();

        setMaxAllowance(params.tokenIn, params.amountIn, oneInchAggregator);

        (bool success, bytes memory result) = oneInchAggregator.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}

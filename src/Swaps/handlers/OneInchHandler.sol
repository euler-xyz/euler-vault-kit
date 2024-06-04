// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

abstract contract OneInchHandler is BaseHandler {
    address public immutable oneInchAggregator;

    constructor(address _oneInchAggregator) {
        oneInchAggregator = _oneInchAggregator;
    }

    function swap(SwapParams memory params) public virtual override {
        if (params.mode != SWAPMODE_EXACT_IN) revert Swapper_UnsupportedMode();

        setMaxAllowance(params.tokenIn, oneInchAggregator);

        (bool success, bytes memory result) = oneInchAggregator.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}

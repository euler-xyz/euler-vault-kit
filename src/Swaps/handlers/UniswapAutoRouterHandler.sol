// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "../../EVault/shared/lib/RevertBytes.sol";

abstract contract UniswapAutoRouterHandler is BaseHandler {
    address public immutable uniSwapRouter02;

    constructor(address _uniSwapRouter02) {
        uniSwapRouter02 = _uniSwapRouter02;
    }

    function swap(SwapParams memory params) public virtual override {
        // TODO why wasn't it handling repays?
        if (params.mode == SWAPMODE_TARGET_DEBT) revert SwapHandler_UnsupportedMode();

        setMaxAllowance(params.tokenIn, uniSwapRouter02);

        (bool success, bytes memory result) = uniSwapRouter02.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}

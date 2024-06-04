// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "../EVault/IEVault.sol";
import {SafeERC20Lib} from "../EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "../EVault/shared/lib/RevertBytes.sol";

import {OneInchHandler} from "./handlers/OneInchHandler.sol";
import {UniswapV2Handler} from "./handlers/UniswapV2Handler.sol";
import {UniswapV3Handler} from "./handlers/UniswapV3Handler.sol";
import {UniswapAutoRouterHandler} from "./handlers/UniswapAutoRouterHandler.sol";

contract Swapper is OneInchHandler, UniswapV2Handler, UniswapV3Handler, UniswapAutoRouterHandler {
    uint256 internal constant HANDLER_ONE_INCH = 0;
    uint256 internal constant HANDLER_UNISWAP_V2 = 1;
    uint256 internal constant HANDLER_UNISWAP_V3 = 2;
    uint256 internal constant HANDLER_UNISWAP_AUTOROUTER = 3;

    uint256 internal constant REENTRANCYLOCK_UNLOCKED = 1;
    uint256 internal constant REENTRANCYLOCK_LOCKED = 2;

    uint256 private reentrancyLock;

    error Swapper_UnknownMode();
    error Swapper_UnknownHandler();
    error Swapper_Reentrancy();

    modifier externalLock() {
        bool isExternal = msg.sender != address(this);

        if (isExternal) {
            if (reentrancyLock == REENTRANCYLOCK_LOCKED) revert Swapper_Reentrancy();
            reentrancyLock = REENTRANCYLOCK_LOCKED;
        }

        _;

        if (isExternal) reentrancyLock = REENTRANCYLOCK_UNLOCKED;
    }

    constructor(address oneInchAggregator, address uniswapRouterV2, address uniswapRouterV3, address uniSwapRouter02)
        OneInchHandler(oneInchAggregator)
        UniswapV2Handler(uniswapRouterV2)
        UniswapV3Handler(uniswapRouterV3)
        UniswapAutoRouterHandler(uniSwapRouter02)
    {}

    function swap(SwapParams memory params)
        public
        override (OneInchHandler, UniswapV2Handler, UniswapV3Handler, UniswapAutoRouterHandler)
        externalLock
    {
        if (params.mode >= SWAPMODE_MAX_VALUE) revert Swapper_UnknownMode();

        if (params.handler == HANDLER_ONE_INCH) {
            OneInchHandler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V2) {
            UniswapV2Handler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_V3) {
            UniswapV3Handler.swap(params);
        } else if (params.handler == HANDLER_UNISWAP_AUTOROUTER) {
            UniswapAutoRouterHandler.swap(params);
        } else {
            revert Swapper_UnknownHandler();
        }

        if (params.mode == SWAPMODE_EXACT_IN) return;

        // swapping to target debt is only useful for repaying
        if (params.mode == SWAPMODE_TARGET_DEBT) {
            uint256 balance = IERC20(params.tokenOut).balanceOf(address(this));
            repay(params.tokenOut, params.receiver, balance, params.account);
        }

        // return unused input token after exact out swap. Caller contract should check amountInMax and skim immediately
        sweep(params.tokenIn, 0, params.sender);
    }


    // in case of over-swapping to repay, pass max uint amount
    function repay(address token, address vault, uint256 amount, address account) public externalLock {
        setMaxAllowance(token, vault);

        IEVault(vault).repay(amount, account);
    }

    // ignore dust with amountMin
    function sweep(address token, uint256 amountMin, address receiver) public externalLock {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amountMin) {
            SafeERC20Lib.safeTransfer(IERC20(token), receiver, balance);
        }
    }

    function multicall(bytes[] memory calls) external externalLock {
        for (uint256 i; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).call(calls[i]);
            if (!success) RevertBytes.revertBytes(result);
        }
    }
}

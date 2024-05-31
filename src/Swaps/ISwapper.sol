// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface ISwapper {
    struct SwapParams {
        uint256 handler;
        uint256 mode;
        address account;
        address tokenIn;
        address tokenOut;
        address vaultIn;
        address receiver;
        uint256 amountIn;
        uint256 amountOut; // in TARGET_DEBT mode, amount of debt the account should have
        bytes data;
    }

    function swap(SwapParams calldata params) external;
}

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
        address receiver; // in TARGET_DEBT liability vault
        uint256 amountOut; // in EXACT_OUT amount of tokenOut to buy, in TARGET_DEBT mode, amount of debt the account should have
        bytes data;
    }

    function swap(SwapParams calldata params) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Simplest possible periphery implementation, used for testing integration with the
// real uniswap core contracts.

// Adapted from uniswap-v3-periphery/contracts/test/TestUniswapV3Callee.sol

import "../../EVault/IEVault.sol";

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract SimpleUniswapPeriphery {
    function swapExact0For1(address pool, uint256 amount0In, address recipient, uint160 sqrtPriceLimitX96) external {
        IUniswapV3Pool(pool).swap(recipient, true, int256(amount0In), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swap0ForExact1(address pool, uint256 amount1Out, address recipient, uint160 sqrtPriceLimitX96) external {
        IUniswapV3Pool(pool).swap(recipient, true, -int256(amount1Out), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swapExact1For0(address pool, uint256 amount1In, address recipient, uint160 sqrtPriceLimitX96) external {
        IUniswapV3Pool(pool).swap(recipient, false, int256(amount1In), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swap1ForExact0(address pool, uint256 amount0Out, address recipient, uint160 sqrtPriceLimitX96) external {
        IUniswapV3Pool(pool).swap(recipient, false, int256(amount0Out), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swapToLowerSqrtPrice(address pool, uint160 sqrtPriceX96, address recipient) external {
        IUniswapV3Pool(pool).swap(recipient, true, type(int256).max, sqrtPriceX96, abi.encode(msg.sender));
    }

    function swapToHigherSqrtPrice(address pool, uint160 sqrtPriceX96, address recipient) external {
        IUniswapV3Pool(pool).swap(recipient, false, type(int256).max, sqrtPriceX96, abi.encode(msg.sender));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        address sender = abi.decode(data, (address));

        if (amount0Delta > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        } else {
            // if both are not gt 0, both must be 0.
            assert(amount0Delta == 0 && amount1Delta == 0);
        }
    }

    function mint(address pool, address recipient, int24 tickLower, int24 tickUpper, uint128 amount) external {
        IUniswapV3Pool(pool).mint(recipient, tickLower, tickUpper, amount, abi.encode(msg.sender));
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
        address sender = abi.decode(data, (address));

        if (amount0Owed > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token0()).transferFrom(sender, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token1()).transferFrom(sender, msg.sender, amount1Owed);
        }
    }
}

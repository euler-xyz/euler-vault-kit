// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./MockUniswapV3Pool.sol";

contract MockUniswapV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;

    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public parameters;

    function deploy(address factory, address token0, address token1, uint24 fee, int24 tickSpacing)
        internal
        returns (address pool)
    {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new MockUniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }

    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(getPool[token0][token1][fee] == address(0));

        pool = deploy(address(this), token0, token1, fee, 0);
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;
    }

    function setPoolAddress(address tokenA, address tokenB, uint24 fee, address newAddress) external {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        getPool[token0][token1][fee] = newAddress;
        getPool[token1][token0][fee] = newAddress;
    }
}

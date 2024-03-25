// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../vendor/TickMath.sol";

interface IUniswapV3PoolDeployer {
    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing);
}

contract MockUniswapV3Pool {
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    constructor() {
        (factory, token0, token1, fee,) = IUniswapV3PoolDeployer(msg.sender).parameters();
    }

    uint160 currSqrtPriceX96;
    int24 currTwap;
    bool throwOld;
    bool throwNotInitiated;
    bool throwOther;
    bool throwEmpty;

    function mockSetTwap(uint160 sqrtPriceX96) public {
        currSqrtPriceX96 = sqrtPriceX96;
        currTwap = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function initialize(uint160 sqrtPriceX96) external {
        mockSetTwap(sqrtPriceX96);
    }

    function mockSetThrowOld(bool val) external {
        throwOld = val;
    }

    function mockSetThrowNotInitiated(bool val) external {
        throwNotInitiated = val;
    }

    function mockSetThrowOther(bool val) external {
        throwOther = val;
    }

    function mockSetThrowEmpty(bool val) external {
        throwEmpty = val;
    }

    function observations(uint256) external pure returns (uint32, int56, uint160, bool) {
        return (0, 0, 0, true);
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        sqrtPriceX96 = currSqrtPriceX96;

        // These fields are tested with the real uniswap core contracts:
        observationIndex = observationCardinality = observationCardinalityNext = 1;

        // Not used in Euler tests:
        tick = 0;
        feeProtocol = 0;
        unlocked = false;
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives)
    {
        require(!throwOld, "OLD");
        require(!throwOther, "OTHER");

        require(secondsAgos.length == 2, "uniswap-pool-mock/unsupported-args-1");
        require(secondsAgos[1] == 0, "uniswap-pool-mock/unsupported-args-2");
        require(secondsAgos[0] > 0, "uniswap-pool-mock/unsupported-args-3");

        tickCumulatives = new int56[](2);
        liquidityCumulatives = new uint160[](2);

        tickCumulatives[0] = 0;
        tickCumulatives[1] = int56(currTwap) * int56(uint56(secondsAgos[0]));
        liquidityCumulatives[0] = liquidityCumulatives[1] = 0;
    }

    function increaseObservationCardinalityNext(uint16) external {
        // This function is tested with the real uniswap core contracts
        require(!throwNotInitiated, "LOK");
        require(!throwOther, "OTHER");
        require(!throwEmpty);
        throwNotInitiated = throwNotInitiated; // suppress visibility warning
    }

    uint128 public liquidity = 100;

    function mockSetLiquidity(uint128 newLiquidity) external {
        liquidity = newLiquidity;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";

/// @title UniswapV3Oracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Adapter for Uniswap V3's TWAP oracle.
/// @dev This oracle supports quoting tokenA/tokenB and tokenB/tokenA of the given pool.
contract UniswapV3Oracle is BaseAdapter {
    /// @dev The minimum length of the TWAP window is 1 minute.
    uint32 internal constant MIN_TWAP_WINDOW = 60 seconds;
    /// @notice One of the tokens in the pool.
    address public immutable tokenA;
    /// @notice The other token in the pool.
    address public immutable tokenB;
    /// @notice The fee tier of the pool.
    uint24 public immutable fee;
    /// @notice The desired length of the twap window.
    uint32 public immutable twapWindow;
    /// @notice The address of the Uniswap V3 pool.
    address public immutable pool;

    /// @notice Deploy a UniswapV3Oracle.
    /// @dev The oracle will support tokenA/tokenB and tokenB/tokenA pricing.
    /// @param _tokenA One of the tokens in the pool.
    /// @param _tokenB The other token in the pool.
    /// @param _fee The fee tier of the pool.
    /// @param _twapWindow The desired length of the twap window.
    /// @param _uniswapV3Factory The address of the Uniswap V3 Factory.
    constructor(address _tokenA, address _tokenB, uint24 _fee, uint32 _twapWindow, address _uniswapV3Factory) {
        if (_twapWindow < MIN_TWAP_WINDOW) revert Errors.PriceOracle_InvalidConfiguration();
        tokenA = _tokenA;
        tokenB = _tokenB;
        fee = _fee;
        twapWindow = _twapWindow;
        pool = IUniswapV3Factory(_uniswapV3Factory).getPool(tokenA, tokenB, _fee);
        if (pool == address(0)) revert Errors.PriceOracle_InvalidConfiguration();
    }

    /// @notice Get a quote by calling the pool's TWAP oracle.
    /// @param inAmount The amount of `base` to convert.
    /// @param base The token that is being priced. Either `tokenA` or `tokenB`.
    /// @param quote The token that is the unit of account. Either `tokenB` or `tokenA`.
    /// @return The converted amount.
    function _getQuote(uint256 inAmount, address base, address quote) internal view override returns (uint256) {
        if (!((base == tokenA && quote == tokenB) || (base == tokenB && quote == tokenA))) {
            revert Errors.PriceOracle_NotSupported(base, quote);
        }
        // Size limitation enforced by the pool.
        if (inAmount > type(uint128).max) revert Errors.PriceOracle_Overflow();

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapWindow;

        // Calculate the mean tick over the twap window.
        (int56[] memory tickCumulatives,) = IUniswapV3Pool(pool).observe(secondsAgos);
        int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int32(twapWindow));
        return OracleLibrary.getQuoteAtTick(tick, uint128(inAmount), base, quote);
    }
}

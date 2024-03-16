// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";
import {IReth} from "src/adapter/rocketpool/IReth.sol";

/// @title RethOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Adapter for pricing Rocket Pool rETH <-> ETH via the rETH contract.
contract RethOracle is BaseAdapter {
    /// @dev The address of Wrapped Ether.
    address public immutable weth;
    /// @dev The address of Rocket Pool rETH.
    address public immutable reth;

    /// @notice Deploy a RethOracle.
    /// @param _weth The address of Wrapped Ether.
    /// @param _reth The address of Rocket Pool rETH.
    /// @dev The oracle will support rETH/WETH and WETH/rETH pricing.
    constructor(address _weth, address _reth) {
        weth = _weth;
        reth = _reth;
    }

    /// @notice Get a quote by querying the exchange rate from the rETH contract.
    /// @dev Calls `getEthValue` for rETH/WETH and `getRethValue` for WETH/rETH.
    /// @param inAmount The amount of `base` to convert.
    /// @param base The token that is being priced. Either `rETH` or `WETH`.
    /// @param quote The token that is the unit of account. Either `WETH` or `rETH`.
    /// @return The converted amount.
    function _getQuote(uint256 inAmount, address base, address quote) internal view override returns (uint256) {
        if (base == reth && quote == weth) {
            return IReth(reth).getEthValue(inAmount);
        } else if (base == weth && quote == reth) {
            return IReth(reth).getRethValue(inAmount);
        }
        revert Errors.PriceOracle_NotSupported(base, quote);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";
import {IStEth} from "src/adapter/lido/IStEth.sol";

/// @title LidoOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Adapter for pricing Lido stEth <-> wstEth via the stEth contract.
contract LidoOracle is BaseAdapter {
    /// @dev The address of Lido staked Ether.
    address public immutable stEth;
    /// @dev The address of Lido wrapped staked Ether.
    address public immutable wstEth;

    /// @notice Deploy a LidoOracle.
    /// @param _stEth The address of Lido staked Ether.
    /// @param _wstEth The address of Lido wrapped staked Ether.
    /// @dev The oracle will support stEth/wstEth and wstEth/stEth pricing.
    constructor(address _stEth, address _wstEth) {
        stEth = _stEth;
        wstEth = _wstEth;
    }

    /// @notice Get a quote by querying the exchange rate from the stEth contract.
    /// @dev Calls `getSharesByPooledEth` for stEth/wstEth and `getPooledEthByShares` for wstEth/stEth.
    /// @param inAmount The amount of `base` to convert.
    /// @param base The token that is being priced. Either `stEth` or `wstEth`.
    /// @param quote The token that is the unit of account. Either `wstEth` or `stEth`.
    /// @return The converted amount.
    function _getQuote(uint256 inAmount, address base, address quote) internal view override returns (uint256) {
        if (base == stEth && quote == wstEth) {
            return IStEth(stEth).getSharesByPooledEth(inAmount);
        } else if (base == wstEth && quote == stEth) {
            return IStEth(stEth).getPooledEthByShares(inAmount);
        }
        revert Errors.PriceOracle_NotSupported(base, quote);
    }
}

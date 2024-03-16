// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";
import {Errors} from "src/lib/Errors.sol";

/// @title BaseAdapter
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Abstract adapter with virtual bid/ask pricing.
abstract contract BaseAdapter is IPriceOracle {
    /// @inheritdoc IPriceOracle
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        return _getQuote(inAmount, base, quote);
    }

    /// @inheritdoc IPriceOracle
    /// @dev Does not support true bid/ask pricing.
    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        uint256 outAmount = _getQuote(inAmount, base, quote);
        return (outAmount, outAmount);
    }

    function _getQuote(uint256, address, address) internal view virtual returns (uint256);
}

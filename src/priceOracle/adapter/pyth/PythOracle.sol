// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPyth} from "@pyth/IPyth.sol";
import {PythStructs} from "@pyth/PythStructs.sol";
import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";
import {ScaleUtils, Scale} from "src/lib/ScaleUtils.sol";

/// @title PythOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice PriceOracle adapter for Pyth pull-based price feeds.
contract PythOracle is BaseAdapter {
    /// @dev The confidence interval can be at most (-5%,+5%) wide.
    uint256 internal constant MAX_CONF_WIDTH = 500;
    /// @notice The address of the Pyth oracle proxy.
    address public immutable pyth;
    /// @notice The address of the base asset corresponding to the feed.
    address public immutable base;
    /// @notice The address of the quote asset corresponding to the feed.
    address public immutable quote;
    /// @notice The id of the feed in the Pyth network.
    /// @dev See https://pyth.network/developers/price-feed-ids.
    bytes32 public immutable feedId;
    /// @notice The maximum allowed age of the price.
    uint256 public immutable maxStaleness;
    /// @dev Used for correcting for the decimals of base and quote.
    uint8 internal immutable baseDecimals;
    /// @dev Used for correcting for the decimals of base and quote.
    uint8 internal immutable quoteDecimals;

    /// @notice Deploy a PythOracle.
    /// @param _pyth The address of the Pyth oracle proxy.
    /// @param _base The address of the base asset corresponding to the feed.
    /// @param _quote The address of the quote asset corresponding to the feed.
    /// @param _feedId The id of the feed in the Pyth network.
    /// @param _maxStaleness The maximum allowed age of the price.
    constructor(address _pyth, address _base, address _quote, bytes32 _feedId, uint256 _maxStaleness) {
        pyth = _pyth;
        base = _base;
        quote = _quote;
        feedId = _feedId;
        maxStaleness = _maxStaleness;
        baseDecimals = IERC20(_base).decimals();
        quoteDecimals = IERC20(_quote).decimals();
    }

    /// @notice Update the price of the Pyth feed.
    /// @param updateData Price update data. Must be fetched off-chain.
    /// @dev The required fee can be computed by calling `getUpdateFee` on Pyth with the length of the `updateData` array.
    function updatePrice(bytes[] calldata updateData) external payable {
        IPyth(pyth).updatePriceFeeds{value: msg.value}(updateData);
    }

    /// @notice Fetch the latest Pyth price and transform it to a quote.
    /// @param inAmount The amount of `base` to convert.
    /// @param _base The token that is being priced.
    /// @param _quote The token that is the unit of account.
    /// @return The converted amount.
    function _getQuote(uint256 inAmount, address _base, address _quote) internal view override returns (uint256) {
        bool inverse = ScaleUtils.getDirectionOrRevert(_base, base, _quote, quote);

        PythStructs.Price memory priceStruct = _fetchPriceStruct();
        uint256 price = uint256(uint64(priceStruct.price));

        Scale scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, int8(priceStruct.expo));
        return ScaleUtils.calcOutAmount(inAmount, price, scale, inverse);
    }

    /// @notice Get the latest Pyth price and perform sanity checks.
    /// @dev Reverts if price is non-positive, confidence is too wide, or exponent is too large.
    function _fetchPriceStruct() internal view returns (PythStructs.Price memory) {
        PythStructs.Price memory p = IPyth(pyth).getPriceNoOlderThan(feedId, maxStaleness);
        if (p.price <= 0 || p.conf > uint64(p.price) * MAX_CONF_WIDTH / 10_000 || p.expo > 16 || p.expo < -16) {
            revert Errors.PriceOracle_InvalidAnswer();
        }
        return p;
    }
}

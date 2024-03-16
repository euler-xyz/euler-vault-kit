// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {RedstoneDefaultsLib} from "@redstone/evm-connector/core/RedstoneDefaultsLib.sol";
import {PrimaryProdDataServiceConsumerBase} from
    "@redstone/evm-connector/data-services/PrimaryProdDataServiceConsumerBase.sol";
import {BaseAdapter, Errors} from "src/adapter/BaseAdapter.sol";
import {ScaleUtils, Scale} from "src/lib/ScaleUtils.sol";

/// @title RedstoneCoreOracle
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Adapter for Redstone pull-based price feeds.
/// @dev To use the oracle, fetch the update data off-chain,
/// call `updatePrice` to update `lastPrice` and then call `getQuote`.
contract RedstoneCoreOracle is PrimaryProdDataServiceConsumerBase, BaseAdapter {
    uint8 internal constant FEED_DECIMALS = 8;
    /// @notice The address of the base asset corresponding to the feed.
    address public immutable base;
    /// @notice The address of the quote asset corresponding to the feed.
    address public immutable quote;
    /// @notice The identifier of the price feed.
    /// @dev See https://app.redstone.finance/#/app/data-services/redstone-primary-prod
    bytes32 public immutable feedId;
    /// @notice The maximum allowed age of the price.
    uint256 public immutable maxStaleness;
    /// @notice The scale factors used for decimal conversions.
    Scale internal immutable scale;
    /// @notice The last updated price.
    /// @dev This gets updated after calling `updatePrice`.
    uint208 public lastPrice;
    /// @notice The timestamp of the last update.
    /// @dev Gets updated ot `block.timestamp` after calling `updatePrice`.
    uint48 public lastUpdatedAt;

    /// @notice Deploy a RedstoneCoreOracle.
    /// @param _base The address of the base asset corresponding to the feed.
    /// @param _quote The address of the quote asset corresponding to the feed.
    /// @param _feedId The identifier of the price feed.
    /// @param _maxStaleness The maximum allowed age of the price.
    /// @dev Base and quote are not required to correspond to the feed assets.
    /// For example, the ETH/USD feed can be used to price WETH/USDC.
    constructor(address _base, address _quote, bytes32 _feedId, uint256 _maxStaleness) {
        if (_maxStaleness < RedstoneDefaultsLib.DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert Errors.PriceOracle_InvalidConfiguration();
        }

        base = _base;
        quote = _quote;
        feedId = _feedId;
        maxStaleness = _maxStaleness;
        uint8 baseDecimals = IERC20(base).decimals();
        uint8 quoteDecimals = IERC20(quote).decimals();
        scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, FEED_DECIMALS);
    }

    /// @notice Ingest a signed update message and cache it on the contract.
    /// @dev Validation logic inherited from PrimaryProdDataServiceConsumerBase.
    function updatePrice() external {
        // Use the cache if the previous price is still fresh.
        if (block.timestamp < lastUpdatedAt + maxStaleness) return;

        uint256 price = getOracleNumericValueFromTxMsg(feedId);
        if (price > type(uint208).max) revert Errors.PriceOracle_Overflow();
        lastPrice = uint208(price);
        lastUpdatedAt = uint48(block.timestamp);
    }

    /// @notice Get the quote from the Redstone feed.
    /// @param inAmount The amount of `base` to convert.
    /// @param _base The token that is being priced.
    /// @param _quote The token that is the unit of account.
    /// @return The converted amount using the Redstone feed.
    function _getQuote(uint256 inAmount, address _base, address _quote) internal view override returns (uint256) {
        bool inverse = ScaleUtils.getDirectionOrRevert(_base, base, _quote, quote);

        uint256 staleness = block.timestamp - lastUpdatedAt;
        if (staleness > maxStaleness) revert Errors.PriceOracle_TooStale(staleness, maxStaleness);

        return ScaleUtils.calcOutAmount(inAmount, lastPrice, scale, inverse);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {Errors} from "src/lib/Errors.sol";
import {Governable} from "src/lib/Governable.sol";

contract FeedRegistry is Governable {
    address public immutable quote;
    mapping(bytes32 feedId => address base) public feeds;

    event FeedSet(bytes32 indexed feedId, address indexed base);

    constructor(address _governor, address _quote) Governable(_governor) {
        quote = _quote;
    }

    function setFeeds(bytes32[] calldata feedIds, address[] calldata bases) external onlyGovernor {
        _setFeeds(feedIds, bases);
    }

    function _setFeeds(bytes32[] calldata _feedIds, address[] calldata _bases) internal {
        if (_feedIds.length != _bases.length) revert Errors.PriceOracle_InvalidConfiguration();
        for (uint256 i = 0; i < _feedIds.length; ++i) {
            _setFeed(_feedIds[i], _bases[i]);
        }
    }

    function _setFeed(bytes32 _feedId, address _base) internal {
        if (feeds[_feedId] != address(0)) revert Errors.PriceOracle_InvalidConfiguration();
        feeds[_feedId] = _base;
        emit FeedSet(_feedId, _base);
    }
}

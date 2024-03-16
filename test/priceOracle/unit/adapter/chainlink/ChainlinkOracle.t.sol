// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {boundAddr} from "test/utils/TestUtils.sol";
import {AggregatorV3Interface} from "src/adapter/chainlink/AggregatorV3Interface.sol";
import {ChainlinkOracle} from "src/adapter/chainlink/ChainlinkOracle.sol";
import {Errors} from "src/lib/Errors.sol";

contract ChainlinkOracleTest is Test {
    struct FuzzableConfig {
        address base;
        address quote;
        address feed;
        uint256 maxStaleness;
        uint8 baseDecimals;
        uint8 quoteDecimals;
        uint8 feedDecimals;
    }

    struct FuzzableRoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    ChainlinkOracle oracle;

    function test_Constructor_Integrity(FuzzableConfig memory c) public {
        _deploy(c);
        assertEq(oracle.base(), c.base);
        assertEq(oracle.quote(), c.quote);
        assertEq(oracle.feed(), c.feed);
        assertEq(oracle.maxStaleness(), c.maxStaleness);
    }

    function test_GetQuote_RevertsWhen_NotSupported_Base(FuzzableConfig memory c, address base, uint256 inAmount)
        public
    {
        _deploy(c);
        vm.assume(base != c.base);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, c.quote));
        oracle.getQuote(inAmount, base, c.quote);
    }

    function test_GetQuote_RevertsWhen_NotSupported_Quote(FuzzableConfig memory c, address quote, uint256 inAmount)
        public
    {
        _deploy(c);
        vm.assume(quote != c.quote);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, c.base, quote));
        oracle.getQuote(inAmount, c.base, quote);
    }

    function test_GetQuote_RevertsWhen_AggregatorV3Reverts(FuzzableConfig memory c, uint256 inAmount) public {
        _deploy(c);

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCallRevert(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), "oops");
        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_ZeroPrice(FuzzableConfig memory c, FuzzableRoundData memory d, uint256 inAmount)
        public
    {
        _deploy(c);
        _prepareValidRoundData(d);
        d.answer = 0;

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_NegativePrice(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        int256 chainlinkAnswer
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        chainlinkAnswer = bound(chainlinkAnswer, type(int256).min, -1);
        d.answer = chainlinkAnswer;

        inAmount = bound(inAmount, 1, type(uint128).max);
        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_TooStale(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        vm.assume(timestamp > d.updatedAt && timestamp - d.updatedAt > c.maxStaleness);

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.warp(timestamp);
        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.PriceOracle_TooStale.selector, timestamp - d.updatedAt, c.maxStaleness)
        );
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_Integrity(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        timestamp = bound(timestamp, d.updatedAt, d.updatedAt + c.maxStaleness);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.warp(timestamp);
        uint256 outAmount = oracle.getQuote(inAmount, c.base, c.quote);
        uint256 expectedOutAmount =
            (inAmount * uint256(d.answer) * 10 ** c.quoteDecimals) / 10 ** (c.feedDecimals + c.baseDecimals);
        assertEq(outAmount, expectedOutAmount);
    }

    function test_GetQuote_Integrity_Inverse(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        timestamp = bound(timestamp, d.updatedAt, d.updatedAt + c.maxStaleness);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.warp(timestamp);
        uint256 outAmount = oracle.getQuote(inAmount, c.quote, c.base);
        uint256 expectedOutAmount =
            (inAmount * 10 ** (c.feedDecimals + c.baseDecimals)) / (uint256(d.answer) * 10 ** c.quoteDecimals);
        assertEq(outAmount, expectedOutAmount);
    }

    function test_GetQuotes_RevertsWhen_NotSupported_Base(FuzzableConfig memory c, address base, uint256 inAmount)
        public
    {
        _deploy(c);
        vm.assume(base != c.base);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, c.quote));
        oracle.getQuotes(inAmount, base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_NotSupported_Quote(FuzzableConfig memory c, address quote, uint256 inAmount)
        public
    {
        _deploy(c);
        vm.assume(quote != c.quote);

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, c.base, quote));
        oracle.getQuotes(inAmount, c.base, quote);
    }

    function test_GetQuotes_RevertsWhen_AggregatorV3Reverts(FuzzableConfig memory c, uint256 inAmount) public {
        _deploy(c);

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCallRevert(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), "oops");
        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_ZeroPrice(FuzzableConfig memory c, FuzzableRoundData memory d, uint256 inAmount)
        public
    {
        _deploy(c);
        _prepareValidRoundData(d);
        d.answer = 0;

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_NegativePrice(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        int256 chainlinkAnswer
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        chainlinkAnswer = bound(chainlinkAnswer, type(int256).min, -1);
        d.answer = chainlinkAnswer;

        inAmount = bound(inAmount, 1, type(uint128).max);
        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_TooStale(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        vm.assume(timestamp > d.updatedAt && timestamp - d.updatedAt > c.maxStaleness);

        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.warp(timestamp);
        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.PriceOracle_TooStale.selector, timestamp - d.updatedAt, c.maxStaleness)
        );
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_Integrity(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        timestamp = bound(timestamp, d.updatedAt, d.updatedAt + c.maxStaleness);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.warp(timestamp);
        (uint256 bidOutAmount, uint256 askOutAmount) = oracle.getQuotes(inAmount, c.base, c.quote);
        uint256 expectedOutAmount =
            (inAmount * uint256(d.answer) * 10 ** c.quoteDecimals) / 10 ** (c.feedDecimals + c.baseDecimals);
        assertEq(bidOutAmount, expectedOutAmount);
        assertEq(askOutAmount, expectedOutAmount);
    }

    function test_GetQuotes_Integrity_Inverse(
        FuzzableConfig memory c,
        FuzzableRoundData memory d,
        uint256 inAmount,
        uint256 timestamp
    ) public {
        _deploy(c);
        _prepareValidRoundData(d);
        timestamp = bound(timestamp, d.updatedAt, d.updatedAt + c.maxStaleness);
        inAmount = bound(inAmount, 1, type(uint128).max);

        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(d));
        vm.warp(timestamp);
        (uint256 bidOutAmount, uint256 askOutAmount) = oracle.getQuotes(inAmount, c.quote, c.base);
        uint256 expectedOutAmount =
            (inAmount * 10 ** (c.feedDecimals + c.baseDecimals)) / (uint256(d.answer) * 10 ** c.quoteDecimals);
        assertEq(bidOutAmount, expectedOutAmount);
        assertEq(askOutAmount, expectedOutAmount);
    }

    function _deploy(FuzzableConfig memory c) private {
        c.base = boundAddr(c.base);
        c.quote = boundAddr(c.quote);
        c.feed = boundAddr(c.feed);
        vm.assume(c.base != c.quote && c.quote != c.feed && c.base != c.feed);

        c.maxStaleness = bound(c.maxStaleness, 0, type(uint128).max);

        c.baseDecimals = uint8(bound(c.baseDecimals, 2, 18));
        c.quoteDecimals = uint8(bound(c.quoteDecimals, 2, 18));
        c.feedDecimals = uint8(bound(c.feedDecimals, 2, 18));

        vm.mockCall(c.base, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(c.baseDecimals));
        vm.mockCall(c.quote, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(c.quoteDecimals));
        vm.mockCall(c.feed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(c.feedDecimals));

        oracle = new ChainlinkOracle(c.base, c.quote, c.feed, c.maxStaleness);
    }

    function _prepareValidRoundData(FuzzableRoundData memory d) private pure {
        d.answer = bound(d.answer, 1, (type(int64).max));
        d.updatedAt = bound(d.updatedAt, 1, type(uint128).max);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPyth} from "@pyth/IPyth.sol";
import {PythStructs} from "@pyth/PythStructs.sol";
import {boundAddr} from "test/utils/TestUtils.sol";
import {PythOracle} from "src/adapter/pyth/PythOracle.sol";
import {Errors} from "src/lib/Errors.sol";

contract PythOracleTest is Test {
    struct FuzzableConfig {
        address base;
        address quote;
        bytes32 feedId;
        uint256 maxStaleness;
        uint8 baseDecimals;
        uint8 quoteDecimals;
    }

    address PYTH = makeAddr("PYTH");
    PythOracle oracle;

    function test_Constructor_Integrity(FuzzableConfig memory c) public {
        _deploy(c);

        assertEq(address(oracle.pyth()), PYTH);
        assertEq(oracle.base(), c.base);
        assertEq(oracle.quote(), c.quote);
        assertEq(oracle.feedId(), c.feedId);
        assertEq(oracle.maxStaleness(), c.maxStaleness);
    }

    function test_GetQuote_Integrity_Concrete(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 18;
        c.quoteDecimals = 6;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 4000, conf: 1, expo: 0, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e18, c.base, c.quote), 4000e6);
        assertEq(oracle.getQuote(4000e6, c.quote, c.base), 1e18);
    }

    function test_GetQuote_Integrity_Concrete_2(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 18;
        c.quoteDecimals = 6;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 40, conf: 1, expo: 2, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e18, c.base, c.quote), 4000e6);
        assertEq(oracle.getQuote(4000e6, c.quote, c.base), 1e18);
    }

    function test_GetQuote_Integrity_Concrete_3(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 18;
        c.quoteDecimals = 6;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 40, conf: 1, expo: 16, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e18, c.base, c.quote), 40e22);
        assertEq(oracle.getQuote(40e22, c.quote, c.base), 1e18);
    }

    function test_GetQuote_Integrity_Concrete_4(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 18;
        c.quoteDecimals = 6;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 400000, conf: 1, expo: -2, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e18, c.base, c.quote), 4000e6);
        assertEq(oracle.getQuote(4000e6, c.quote, c.base), 1e18);
    }

    function test_GetQuote_Integrity_Concrete_5(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 18;
        c.quoteDecimals = 6;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 40e16, conf: 1, expo: -16, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e18, c.base, c.quote), 40e6);
        assertEq(oracle.getQuote(40e6, c.quote, c.base), 1e18);
    }

    function test_GetQuote_Integrity_Concrete_6(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 6;
        c.quoteDecimals = 18;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 40e16, conf: 1, expo: -16, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e6, c.base, c.quote), 40e18);
        assertEq(oracle.getQuote(40e18, c.quote, c.base), 1e6);
    }

    function test_GetQuote_Integrity_Concrete_7(FuzzableConfig memory c) public {
        _bound(c);
        c.baseDecimals = 2;
        c.quoteDecimals = 18;
        _deploy(c);

        vm.mockCall(
            PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness),
            abi.encode(PythStructs.Price({price: 4, conf: 0, expo: 3, publishTime: 0}))
        );
        assertEq(oracle.getQuote(1e2, c.base, c.quote), 4000e18);
        assertEq(oracle.getQuote(4000e18, c.quote, c.base), 1e2);
    }

    function test_GetQuote_RevertsWhen_InvalidBase(FuzzableConfig memory c, uint256 inAmount, address base) public {
        _deploy(c);
        vm.assume(base != c.base);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, c.quote));
        oracle.getQuote(inAmount, base, c.quote);
    }

    function test_GetQuote_RevertsWhen_InvalidQuote(FuzzableConfig memory c, uint256 inAmount, address quote) public {
        _deploy(c);
        vm.assume(quote != c.quote);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, c.base, quote));
        oracle.getQuote(inAmount, c.base, quote);
    }

    function test_GetQuote_RevertsWhen_ZeroPrice(FuzzableConfig memory c, uint256 inAmount, PythStructs.Price memory p)
        public
    {
        _deploy(c);
        p.price = 0;
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_NegativePrice(
        FuzzableConfig memory c,
        PythStructs.Price memory p,
        uint256 inAmount
    ) public {
        _deploy(c);
        _bound(p);
        p.price = int64(bound(p.price, type(int64).min, -1));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_ConfidenceIntervalGtMaxPrice(
        FuzzableConfig memory c,
        PythStructs.Price memory p,
        uint256 inAmount
    ) public {
        _deploy(c);
        _bound(p);
        p.conf = uint64(bound(p.conf, uint64(type(int64).max) + 1, type(uint64).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_ConfidenceIntervalGtPrice(
        FuzzableConfig memory c,
        PythStructs.Price memory p,
        uint256 inAmount
    ) public {
        _deploy(c);
        _bound(p);
        p.conf = uint64(bound(p.conf, uint64(p.price) + 1, type(uint64).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_ExponentTooSmall(
        FuzzableConfig memory c,
        PythStructs.Price memory p,
        uint256 inAmount
    ) public {
        _deploy(c);
        _bound(p);
        p.expo = int32(bound(p.expo, type(int32).min, -17));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuote_RevertsWhen_ExponentTooLarge(
        FuzzableConfig memory c,
        PythStructs.Price memory p,
        uint256 inAmount
    ) public {
        _deploy(c);
        _bound(p);
        p.expo = int32(bound(p.expo, 17, type(int32).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuote(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_InvalidBase(FuzzableConfig memory c, uint256 inAmount, address base) public {
        _deploy(c);
        vm.assume(base != c.base);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, c.quote));
        oracle.getQuotes(inAmount, base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_InvalidQuote(FuzzableConfig memory c, uint256 inAmount, address quote) public {
        _deploy(c);
        vm.assume(quote != c.quote);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, c.base, quote));
        oracle.getQuotes(inAmount, c.base, quote);
    }

    function test_GetQuotes_RevertsWhen_ZeroPrice(FuzzableConfig memory c, uint256 inAmount, PythStructs.Price memory p)
        public
    {
        _deploy(c);
        p.price = 0;
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_NegativePrice(
        FuzzableConfig memory c,
        uint256 inAmount,
        PythStructs.Price memory p
    ) public {
        _deploy(c);
        _bound(p);
        p.price = int64(bound(p.price, type(int64).min, -1));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_ConfidenceIntervalGtMaxPrice(
        FuzzableConfig memory c,
        uint256 inAmount,
        PythStructs.Price memory p
    ) public {
        _deploy(c);
        _bound(p);
        p.conf = uint64(bound(p.conf, uint64(type(int64).max) + 1, type(uint64).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_ConfidenceIntervalGtPrice(
        FuzzableConfig memory c,
        uint256 inAmount,
        PythStructs.Price memory p
    ) public {
        _deploy(c);
        _bound(p);
        p.conf = uint64(bound(p.conf, uint64(p.price) + 1, type(uint64).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_ExponentTooSmall(
        FuzzableConfig memory c,
        uint256 inAmount,
        PythStructs.Price memory p
    ) public {
        _deploy(c);
        _bound(p);
        p.expo = int32(bound(p.expo, type(int32).min, -17));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_GetQuotes_RevertsWhen_ExponentTooLarge(
        FuzzableConfig memory c,
        uint256 inAmount,
        PythStructs.Price memory p
    ) public {
        _deploy(c);
        _bound(p);
        p.expo = int32(bound(p.expo, 17, type(int32).max));
        vm.mockCall(
            PYTH, abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, c.feedId, c.maxStaleness), abi.encode(p)
        );
        vm.expectRevert(Errors.PriceOracle_InvalidAnswer.selector);
        oracle.getQuotes(inAmount, c.base, c.quote);
    }

    function test_UpdatePrice_Integrity(
        FuzzableConfig memory c,
        address caller,
        bytes[] calldata updateData,
        uint256 value
    ) public {
        _deploy(c);
        caller = boundAddr(caller);
        vm.deal(caller, value);
        vm.mockCall(PYTH, abi.encodeWithSelector(IPyth.updatePriceFeeds.selector, updateData), "");

        vm.prank(caller);
        oracle.updatePrice{value: value}(updateData);
        assertEq(caller.balance, 0);
        assertEq(address(oracle).balance, value);
    }

    function test_UpdatePrice_RevertsWhen_PythCallReverts(
        FuzzableConfig memory c,
        address caller,
        bytes[] calldata updateData,
        uint256 value
    ) public {
        _deploy(c);
        caller = boundAddr(caller);
        vm.deal(caller, value);
        vm.mockCallRevert(PYTH, abi.encodeWithSelector(IPyth.updatePriceFeeds.selector, updateData), "oops");

        vm.expectRevert();
        vm.prank(caller);
        oracle.updatePrice{value: value}(updateData);
        assertEq(caller.balance, value);
        assertEq(address(oracle).balance, 0);
    }

    function _deploy(FuzzableConfig memory c) private {
        _bound(c);
        vm.mockCall(c.base, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(c.baseDecimals));
        vm.mockCall(c.quote, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(c.quoteDecimals));
        oracle = new PythOracle(PYTH, c.base, c.quote, c.feedId, c.maxStaleness);
    }

    function _bound(PythStructs.Price memory p) private pure {
        p.price = int64(bound(p.price, 1, type(int64).max));
        p.conf = uint64(bound(p.conf, 0, uint64(p.price) / 20));
        p.expo = int32(bound(p.expo, -16, 16));
    }

    function _bound(FuzzableConfig memory c) private pure {
        c.base = boundAddr(c.base);
        c.quote = boundAddr(c.quote);
        vm.assume(c.base != c.quote);
        c.baseDecimals = uint8(bound(c.baseDecimals, 0, 18));
        c.quoteDecimals = uint8(bound(c.quoteDecimals, 0, 18));
        c.maxStaleness = uint32(bound(c.maxStaleness, 0, type(uint32).max));
    }
}

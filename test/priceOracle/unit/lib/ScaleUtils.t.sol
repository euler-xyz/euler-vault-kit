// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {ScaleUtils, Scale} from "src/lib/ScaleUtils.sol";
import {Errors} from "src/lib/Errors.sol";

contract ScaleUtilsTest is Test {
    function test_From_RevertsWhen_PriceExponentOOB(uint8 priceExponent, uint8 feedExponent) public {
        priceExponent = uint8(bound(priceExponent, ScaleUtils.MAX_EXPONENT + 1, type(uint8).max));
        feedExponent = uint8(bound(feedExponent, 0, ScaleUtils.MAX_EXPONENT));
        vm.expectRevert(Errors.PriceOracle_Overflow.selector);
        ScaleUtils.from(priceExponent, feedExponent);
    }

    function test_From_RevertsWhen_FeedExponentOOB(uint8 priceExponent, uint8 feedExponent) public {
        priceExponent = uint8(bound(priceExponent, 0, ScaleUtils.MAX_EXPONENT));
        feedExponent = uint8(bound(feedExponent, ScaleUtils.MAX_EXPONENT + 1, type(uint8).max));
        vm.expectRevert(Errors.PriceOracle_Overflow.selector);
        ScaleUtils.from(priceExponent, feedExponent);
    }

    function test_GetDirectionOrRevert_Integrity(address base, address quote) public pure {
        vm.assume(base != quote);
        assertFalse(ScaleUtils.getDirectionOrRevert(base, base, quote, quote));
        assertTrue(ScaleUtils.getDirectionOrRevert(quote, base, base, quote));
    }

    function test_GetDirectionOrRevert_RevertsWhen_InvalidBaseOrQuote(address base, address quote, address other)
        public
    {
        vm.assume(base != quote && quote != other && other != base);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, other, quote));
        ScaleUtils.getDirectionOrRevert(other, base, quote, quote);
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, other));
        ScaleUtils.getDirectionOrRevert(base, base, other, quote);
    }

    function test_CalcScale_Integrity(uint8 baseDecimals, uint8 quoteDecimals, uint8 feedDecimals) public pure {
        quoteDecimals = uint8(bound(quoteDecimals, 0, ScaleUtils.MAX_EXPONENT));
        baseDecimals = uint8(bound(baseDecimals, 0, ScaleUtils.MAX_EXPONENT));
        feedDecimals = uint8(bound(feedDecimals, 0, ScaleUtils.MAX_EXPONENT - baseDecimals));
        Scale scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, feedDecimals);

        uint256 priceScale = (Scale.unwrap(scale) << 128) >> 128;
        uint256 feedScale = Scale.unwrap(scale) >> 128;
        assertEq(priceScale, 10 ** quoteDecimals);
        assertEq(feedScale, 10 ** (feedDecimals + baseDecimals));
    }

    function test_CalcScale_RevertsWhen_PriceScaleOOB(uint8 baseDecimals, uint8 quoteDecimals, uint8 feedDecimals)
        public
    {
        quoteDecimals = uint8(bound(quoteDecimals, ScaleUtils.MAX_EXPONENT + 1, type(uint8).max));
        baseDecimals = uint8(bound(baseDecimals, 0, ScaleUtils.MAX_EXPONENT));
        feedDecimals = uint8(bound(feedDecimals, 0, ScaleUtils.MAX_EXPONENT - baseDecimals));
        vm.expectRevert(Errors.PriceOracle_Overflow.selector);
        ScaleUtils.calcScale(baseDecimals, quoteDecimals, feedDecimals);
    }

    function test_CalcScale_RevertsWhen_FeedScaleOOB(uint8 baseDecimals, uint8 quoteDecimals, uint8 feedDecimals)
        public
    {
        quoteDecimals = uint8(bound(quoteDecimals, 0, ScaleUtils.MAX_EXPONENT));
        feedDecimals = uint8(
            bound(
                feedDecimals,
                baseDecimals > ScaleUtils.MAX_EXPONENT ? 0 : ScaleUtils.MAX_EXPONENT - baseDecimals + 1,
                type(uint8).max - baseDecimals
            )
        );
        vm.expectRevert(Errors.PriceOracle_Overflow.selector);
        ScaleUtils.calcScale(baseDecimals, quoteDecimals, feedDecimals);
    }

    function test_CalcOutAmount_Integrity() public pure {
        uint256 unitPrice = 2000e18;
        uint8 feedDecimals = 18;
        uint8 baseDecimals = 18;
        uint8 quoteDecimals = 2;

        Scale scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, feedDecimals);
        uint256 inAmount = 4e18;
        uint256 outAmount = ScaleUtils.calcOutAmount(inAmount, unitPrice, scale, false);
        uint256 expectedOutAmount = 8000e2;
        assertEq(outAmount, expectedOutAmount);
    }

    function test_CalcOutAmount_Integrity_Inverse() public pure {
        uint256 unitPrice = 2000e18;
        uint8 feedDecimals = 18;
        uint8 baseDecimals = 18;
        uint8 quoteDecimals = 2;

        Scale scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, feedDecimals);
        uint256 inAmount = 8000e2;
        uint256 outAmount = ScaleUtils.calcOutAmount(inAmount, unitPrice, scale, true);
        uint256 expectedOutAmount = 4e18;
        assertEq(outAmount, expectedOutAmount);
    }
}

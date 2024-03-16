// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {IReth} from "src/adapter/rocketpool/IReth.sol";
import {RethOracle} from "src/adapter/rocketpool/RethOracle.sol";
import {Errors} from "src/lib/Errors.sol";

contract RethOracleTest is Test {
    address internal WETH = makeAddr("WETH");
    address internal RETH = makeAddr("RETH");

    RethOracle oracle;

    function setUp() public {
        oracle = new RethOracle(WETH, RETH);
    }

    function test_Constructor_Integrity() public view {
        assertEq(oracle.weth(), WETH);
        assertEq(oracle.reth(), RETH);
    }

    function test_GetQuote_RevertsWhen_InvalidBase_A(uint256 inAmount, address base) public {
        vm.assume(base != RETH);
        address quote = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_InvalidBase_B(uint256 inAmount, address base) public {
        vm.assume(base != WETH);
        address quote = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_InvalidQuote_A(uint256 inAmount, address quote) public {
        vm.assume(quote != RETH);
        address base = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_InvalidQuote_B(uint256 inAmount, address quote) public {
        vm.assume(quote != WETH);
        address base = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_SameTokens_Weth(uint256 inAmount) public {
        address base = WETH;
        address quote = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_SameTokens_Reth(uint256 inAmount) public {
        address base = RETH;
        address quote = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuote(inAmount, base, quote);
    }

    function test_GetQuote_RevertsWhen_Weth_Reth_RethCallReverts(uint256 inAmount) public {
        vm.mockCallRevert(RETH, abi.encodeWithSelector(IReth.getRethValue.selector), "oops");

        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuote(inAmount, WETH, RETH);
    }

    function test_GetQuote_RevertsWhen_Reth_Weth_RethCallReverts(uint256 inAmount) public {
        vm.mockCallRevert(RETH, abi.encodeWithSelector(IReth.getEthValue.selector), "oops");

        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuote(inAmount, RETH, WETH);
    }

    function test_GetQuote_Weth_Reth_Integrity(uint256 inAmount, uint256 expectedOutAmount) public {
        vm.assume(expectedOutAmount != 0);

        vm.mockCall(RETH, abi.encodeWithSelector(IReth.getRethValue.selector), abi.encode(expectedOutAmount));

        uint256 outAmount = oracle.getQuote(inAmount, WETH, RETH);
        assertEq(outAmount, expectedOutAmount);
    }

    function test_GetQuote_Reth_Weth_Integrity(uint256 inAmount, uint256 expectedOutAmount) public {
        vm.assume(expectedOutAmount != 0);

        vm.mockCall(RETH, abi.encodeWithSelector(IReth.getEthValue.selector), abi.encode(expectedOutAmount));

        uint256 outAmount = oracle.getQuote(inAmount, RETH, WETH);
        assertEq(outAmount, expectedOutAmount);
    }

    function test_GetQuotes_RevertsWhen_InvalidBase_A(uint256 inAmount, address base) public {
        vm.assume(base != RETH);
        address quote = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_InvalidBase_B(uint256 inAmount, address base) public {
        vm.assume(base != WETH);
        address quote = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_InvalidQuote_A(uint256 inAmount, address quote) public {
        vm.assume(quote != RETH);
        address base = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_InvalidQuote_B(uint256 inAmount, address quote) public {
        vm.assume(quote != WETH);
        address base = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_SameTokens_Weth(uint256 inAmount) public {
        address base = WETH;
        address quote = WETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_SameTokens_Reth(uint256 inAmount) public {
        address base = RETH;
        address quote = RETH;

        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracle_NotSupported.selector, base, quote));
        oracle.getQuotes(inAmount, base, quote);
    }

    function test_GetQuotes_RevertsWhen_Weth_Reth_RethCallReverts(uint256 inAmount) public {
        vm.mockCallRevert(RETH, abi.encodeWithSelector(IReth.getRethValue.selector), "oops");

        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuotes(inAmount, WETH, RETH);
    }

    function test_GetQuotes_RevertsWhen_Reth_Weth_RethCallReverts(uint256 inAmount) public {
        vm.mockCallRevert(RETH, abi.encodeWithSelector(IReth.getEthValue.selector), "oops");

        vm.expectRevert(abi.encodePacked("oops"));
        oracle.getQuotes(inAmount, RETH, WETH);
    }

    function test_GetQuotes_Weth_Reth_Integrity(uint256 inAmount, uint256 expectedOutAmount) public {
        vm.assume(expectedOutAmount != 0);

        vm.mockCall(RETH, abi.encodeWithSelector(IReth.getRethValue.selector), abi.encode(expectedOutAmount));

        (uint256 bidOutAmount, uint256 askOutAmount) = oracle.getQuotes(inAmount, WETH, RETH);
        assertEq(expectedOutAmount, bidOutAmount);
        assertEq(expectedOutAmount, askOutAmount);
    }

    function test_GetQuotes_Reth_Weth_Integrity(uint256 inAmount, uint256 expectedOutAmount) public {
        vm.assume(expectedOutAmount != 0);

        vm.mockCall(RETH, abi.encodeWithSelector(IReth.getEthValue.selector), abi.encode(expectedOutAmount));

        (uint256 bidOutAmount, uint256 askOutAmount) = oracle.getQuotes(inAmount, RETH, WETH);
        assertEq(expectedOutAmount, bidOutAmount);
        assertEq(expectedOutAmount, askOutAmount);
    }
}

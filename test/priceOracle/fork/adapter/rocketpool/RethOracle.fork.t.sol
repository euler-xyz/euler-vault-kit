// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {RETH, WETH} from "test/utils/EthereumAddresses.sol";
import {ForkTest} from "test/utils/ForkTest.sol";
import {RethOracle} from "src/adapter/rocketpool/RethOracle.sol";
import {Errors} from "src/lib/Errors.sol";

contract RethOracleForkTest is ForkTest {
    RethOracle oracle;

    function setUp() public {
        _setUpFork(19000000);
        oracle = new RethOracle(WETH, RETH);
    }

    function test_GetQuote_Integrity() public view {
        uint256 wethReth = oracle.getQuote(1e18, WETH, RETH);
        assertApproxEqRel(wethReth, 0.9e18, 0.1e18);

        uint256 rethWeth = oracle.getQuote(1e18, RETH, WETH);
        assertApproxEqRel(rethWeth, 1.1e18, 0.1e18);
    }

    function test_GetQuotes_Integrity() public view {
        (uint256 wethRethBid, uint256 wethRethAsk) = oracle.getQuotes(1e18, WETH, RETH);
        assertApproxEqRel(wethRethBid, 0.9e18, 0.1e18);
        assertApproxEqRel(wethRethAsk, 0.9e18, 0.1e18);

        (uint256 rethWethBid, uint256 rethWethAsk) = oracle.getQuotes(1e18, RETH, WETH);
        assertApproxEqRel(rethWethBid, 1.1e18, 0.1e18);
        assertApproxEqRel(rethWethAsk, 1.1e18, 0.1e18);
    }
}

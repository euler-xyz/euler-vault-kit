// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IIRM} from "../../../src/InterestRateModels/IIRM.sol";
import {IRMAdaptiveCurve as EulerIRM} from "../../../src/InterestRateModels/IRMAdaptiveCurve.sol";
import {AdaptiveCurveIrm as MorphoIRM} from "lib/morpho-blue-irm/src/adaptive-curve-irm/AdaptiveCurveIRM.sol";
import {ConstantsLib} from "lib/morpho-blue-irm/src/adaptive-curve-irm/libraries/ConstantsLib.sol";
import {Id, MarketParams, Market} from "lib/morpho-blue-irm/lib/morpho-blue/src/interfaces/IMorpho.sol";

contract StubMorpho {
    MarketParams public _marketParams;
    Market public _market;

    function setBalances(uint256 cash, uint256 borrows) external {
        _market.totalSupplyAssets = uint128(cash + borrows);
        _market.totalBorrowAssets = uint128(borrows);
    }

    function setTimestamp(uint256 timestamp) external {
        _market.lastUpdate = uint128(timestamp);
    }

    function market() external view returns (Market memory) {
        return _market;
    }

    function marketParams() external view returns (MarketParams memory) {
        return _marketParams;
    }
}

contract IRMAdaptiveCurveDiffTest is Test {
    address constant VAULT = address(0x27183);
    address constant MORPHO = address(0x10538);

    EulerIRM eulerIrm;
    MorphoIRM morphoIrm;
    StubMorpho stubMorpho;

    function setUp() public {
        eulerIrm = new EulerIRM(
            ConstantsLib.TARGET_UTILIZATION,
            ConstantsLib.INITIAL_RATE_AT_TARGET,
            ConstantsLib.MIN_RATE_AT_TARGET,
            ConstantsLib.MAX_RATE_AT_TARGET,
            ConstantsLib.CURVE_STEEPNESS,
            ConstantsLib.ADJUSTMENT_SPEED
        );
        morphoIrm = new MorphoIRM(MORPHO);
        stubMorpho = new StubMorpho();
    }

    function test_AdaptiveCurveIRMsEquivalent(uint256 seed) public {
        initializeIrms();

        for (uint256 i = 0; i < 100; ++i) {
            uint256 util = uint256(keccak256(abi.encodePacked(i, seed, "util")));
            uint256 delay = uint256(keccak256(abi.encodePacked(i, seed, "delay")));
            util = _bound(util, 0, 1e18);
            delay = _bound(delay, 0, 1 days);

            uint256 cash;
            uint256 borrows;
            if (util == 0) {
                cash = 0;
                borrows = 0;
            } else if (util == 1e18) {
                cash = 0;
                borrows = 1e18;
            } else {
                cash = 1e18;
                borrows = 1e18 * util / (1e18 - util);
            }

            console2.log("iteration=%s, delay=%s, util=%e", i, delay, util);

            skip(delay);
            assertEquivalent(cash, borrows);
        }
    }

    function initializeIrms() internal {
        stubMorpho.setTimestamp(block.timestamp);
        assertEquivalent(1e18, 9e18);
    }

    function assertEquivalent(uint256 cash, uint256 borrows) internal {
        stubMorpho.setBalances(cash, borrows);
        vm.startPrank(MORPHO);
        uint256 morphoRate = morphoIrm.borrowRate(stubMorpho.marketParams(), stubMorpho.market());
        stubMorpho.setTimestamp(block.timestamp);

        vm.startPrank(VAULT);
        uint256 eulerRate = eulerIrm.computeInterestRate(VAULT, cash, borrows);

        assertApproxEqRel(eulerRate, morphoRate, 0.01e18);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MathTesting} from "../../helpers/MathTesting.sol";
import "forge-std/console.sol";

contract InterestRateLinearSmoothKink is Test, MathTesting {
    function setUp() public {}

    function test_linearSmoothKinkIR() public {
        console.log("here1");
        uint256 ir = computeInterestRateInternal(50e18, 100e18);
        console.log("ir", ir);
        assertEq(ir, ir);
    }

    function computeInterestRateInternal(uint256 cash, uint256 borrows) public returns (uint256) {
        console.log("here2");
        uint256 baseRate = 0;
        uint256 slope1 = 3e18;
        console.log("slope1", slope1);
        // uint32 kink = 3650722206; // utilisation start - 3650722206 is 0.85 in uint32
        // console.log(kink);
        // int256 shape = -5.8e18; // curve 2 shape paramter
        // console.logInt(shape);

        // uint256 totalAssets = cash + borrows;
        
        // uint32 utilization = totalAssets == 0 ? 0 : uint32(borrows * type(uint32).max / totalAssets);

        // uint256 ir = baseRate;

        // if (utilization <= kink) {
        //     ir += utilization * slope1;
        // } else {
        //     unchecked {
        //         int256 ratio = shape
        //             + ((1e18 - shape) * int256(uint256((type(uint32).max - utilization)) / (type(uint32).max - kink)));
        //         uint256 effectiveUtilization =
        //             uint256(int256(uint256(kink)) + (int256(uint256(utilization - kink)) * ratio) / 1e18);
        //         ir += effectiveUtilization * slope1;
        //     }
        // }

        // return ir;
    }
}

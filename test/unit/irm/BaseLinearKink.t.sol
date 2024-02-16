// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BaseIRMLinearKink} from "../../../src/interestRateModels/BaseIRMLinearKink.sol";
import "../../helpers/Math.sol";

contract BaseLinearKink is Test {
    BaseIRMLinearKink irm;

    function setUp() public {
        //IRM default params
        irm = new BaseIRMLinearKink(
            // Base=0% APY,  Kink(50%)=10% APY  Max=300% APY
            0,
            1406417851,
            19050045013,
            2147483648
        );
    }

    function test_MaxIR() public {
        uint precision = 1e12; //8 digits
        uint32 utilisation = getUtilisation(10000); //100%
        uint SPY = getSPY(3*1e17); //300%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_KinkIR() public {
        uint precision = 1e11; //8 digits
        uint32 utilisation = getUtilisation(5000); //50%
        uint SPY = getSPY(1*1e16); //10%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_UnderKinkIR() public {
        uint precision = 1e13; // 6 digits
        uint32 utilisation = getUtilisation(2500); //25%
        uint SPY = getSPY(4880875385828198); //4.88%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_OverKinkIR() public {
        uint precision = 1e13; // 7 digits
        uint32 utilisation = getUtilisation(7500); //75%
        uint SPY = getSPY(109761712896340360); //109.76%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    //utilisation: 100% = 10000
    function getUtilisation(uint16 util) public pure returns(uint32){
        return uint32(Math.mulScale(type(uint32).max, util, 10000));
    }

    //apy: 500% APY = 5 * 1e17
    function getSPY(int128 apy) public pure returns(uint) {
        int apr = Math.ln((apy + 1e17) * (2**64) / 1e17);
        return uint(apr) * 1e27 / 2**64 / (365.2425 * 86400);
    }
}

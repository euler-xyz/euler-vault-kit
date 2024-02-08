// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BaseIRMLinearKink} from "../../../src/interestRateModels/BaseIRMLinearKink.sol";
import "../../helpers/Math.sol";

contract BaseLinearKink is Test {
    BaseIRMLinearKink irm;

    //56778582418225942733  (1.791759469228055 * 1e27 / SECONDS_PER_YEAR) APR(500%) ln(5+1) = 1.791759469228055
    //158443692534057154822  MAX_ALLOWED_INTEREST_RATE (5 * 1e27 / SECONDS_PER_YEAR)

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
        uint precision = 1e12; //8 digit
        uint32 utilisation = getUtilisation(10000); //100%
        uint SPY = getSPY(30000); //300$

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_KinkIR() public {
        uint precision = 1e11; //8 digit
        uint32 utilisation = getUtilisation(5000); //50%
        uint SPY = getSPY(1000); //10%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_UnderKinkIR() public {
        uint precision = 1e17; // 2 digit
        uint32 utilisation = getUtilisation(2500); //25%
        uint SPY = getSPY(488); //4.88%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    function test_OverKinkIR() public {
        uint precision = 1e16; // 4 digit
        uint32 utilisation = getUtilisation(7500); //75%
        uint SPY = getSPY(10976); //109.76%

        uint ir = irm.computeInterestRate(address(0), address(0), utilisation);

        assertEq(ir/precision, SPY/precision);
    }

    //util: 0% - 100%(10000)
    function getUtilisation(uint16 util) public pure returns(uint32){
        return uint32(Math.mulScale(type(uint32).max, util, 10000));
    }

    //apr: 0% - 500%(50000)
    function getSPY(int128 apr) public pure returns(uint) {
        int x = Math.ln((apr+10000) * (2**64) / 10000);
        return uint(x) * 1e27 / 2**64 / (365.2425 * 86400);
    }
}

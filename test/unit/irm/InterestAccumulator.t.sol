// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "../../../src/EVault/shared/lib/RPow.sol";

contract InterestAccumulator is Test {
    uint256 SECONDS_PER_YEAR = 365 * 86400; // Gregorian calendar

    function test_OverTime_SameAPR() public {
        uint precision = 1e25; //7 digits
        uint256 interestAccumulator = 2.2026461744071526e31; //100%APR, 10 years

        uint duration = SECONDS_PER_YEAR * 10;
        uint72 interestRate = uint72(uint256(1 * 1e27) / SECONDS_PER_YEAR); //100%APR

        uint256 resInterestAccumulator = getInterestAccumulator(interestRate, duration);

        assertEq(interestAccumulator/precision, resInterestAccumulator/precision);
    }

    function test_OverTime_DiffAPR() public {
        uint precision = 1e19; //7 digits

        uint256 interestAccumulator100 = 1.5082633604592232e27; //150 days 100%APR
        uint256 interestAccumulator200 = 2.2748583414054674e27; //150 days 200%APR
        uint256 interestAccumulator = interestAccumulator100 * interestAccumulator200 / 1e27; // 300 days 100%APR + 200%APR

        uint256 delta = 86400; //1 day
        uint256 endTime = 300 * 86400; // 300 days
        uint256 lastUpdateTime = block.timestamp;

        uint72 lastInterestRate = uint72(uint256(1 * 1e27) / SECONDS_PER_YEAR); //100%APR
        uint256 lastInterestAccumulator = 1e27; //initial value

        while(lastUpdateTime < endTime){
            vm.warp(block.timestamp + uint256(delta));
            lastInterestAccumulator = getNextInterestAccumulator(lastInterestRate, delta, lastInterestAccumulator);
            lastUpdateTime = block.timestamp;
            if(block.timestamp == (150 * delta) + 1){
                assertEq(interestAccumulator100/precision, lastInterestAccumulator/precision);
                lastInterestRate = uint72(uint256(2 * 1e27) / SECONDS_PER_YEAR); //200%APR
            }
        }
        
        assertEq(interestAccumulator/precision, lastInterestAccumulator/precision);
    }

    function getInterestAccumulator(uint72 interestRate, uint256 duration) public pure returns(uint256) {
        return RPow.rpow(uint256(interestRate) + 1e27, duration, 1e27);
    }

    function getNextInterestAccumulator(uint72 interestRate, uint256 delta, uint256 lastInterestAccumulator) public pure returns(uint256){
        return getInterestAccumulator(interestRate, delta) * lastInterestAccumulator / 1e27;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title CryticToFoundry
/// @notice Foundry wrapper for fuzzer failed call sequences
/// @dev Regression testing for failed call sequences
contract CryticToFoundry is Invariants, Setup {
    modifier setup() override {
        _;
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() public {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        actor = actors[USER1];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    /////////////////////////////////////////////////////////////////////////////////////////////// 

    function test_BM_INVARIANT_O_ROUNDING() public {//@audit-issue breaks because rounds debt vualt down
        this.depositToActor(400,93704952709166092675833692626070333629207815095066323987818791); 
        console.log("Actor: ", address(actor));
        this.enableController(3388611185579509790345271144155567529519710816754010133488659);
        this.setPrice(82722273493907026195652355382983934173897749054150317695866107075, 0.9 ether);
        (uint256 collateralValue, uint256 liabilityValue) = _getAccountLiquidity(address(actor), false);
        console.log("Collateral Value: ", collateralValue);
        console.log("Liability Value: ", liabilityValue);
        console.log("Balance before: ", eTST.balanceOf(address(actor)));
        console.log("Debt before: ", eTST.debtOf(address(actor)));
        assetTST.burn(address(actor), assetTST.balanceOf(address(actor)));
        //this.borrowTo(1,476485543921707036124785589083935854038465196552);


        for (uint256 i = 0; i < 90; i++) {
            console.log("BORROW ################################################");
            vm.prank(address(actor));
            eTST.borrow(1, address(actor));
            console.log("Balance after: ", eTST.balanceOf(address(actor)));
            console.log("Debt after: ", eTST.debtOf(address(actor)));

            console.log("REPAY ################################################");
            vm.prank(address(actor));
            eTST.repay(1, address(actor));
            console.log("Balance after: ", eTST.balanceOf(address(actor)));
            console.log("Debt after: ", eTST.debtOf(address(actor)));

            console.log("WITHDRAW ################################################");


        }
        //this.borrowTo(1,476485543921707036124785589083935854038465196552);


        console.log("Total debt: ", eTST.totalBorrows());
        //echidna_BM_INVARIANT();
    }

    function test_TM_INVARIANT_A() public {//PASS
        this.setPrice(0,1);
        this.enableController(955302625856880925658809642386118260561143748);
        this.loop (4,0);
        assert_TM_INVARIANT_A();
    }

    function test_TM_INVARIANT_C() public {//PASS
        this.enableController(7940019329826366144274892142031768413507269414922630);
        this.setPrice(12009255528033600768137352216945045496365266793106593130770692883, 1);
        this.loop(5430,659532459992408855116845120804223722874433054788209032745);
        _delay(36473);
        console.log("BEFORE");
        this.transferFromTo(0,66989060828690,0);
        console.log("AFTER");

        console.log("Accumulated Fees: ", eTST.accumulatedFees());
        echidna_TM_INVARIANT();
    }

    function test_ERC4626_ACTIONS_INVARIANT() public {//@audit-issue maxMint should never revert
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        this.enableController (7301099788150748633707767049393606426279241562950386710103457664483);   
        this.setPrice (4386488222306922885577240690251822105318053011780346557732883264202, 1);
        this.loop(864261200,42413089974244492524697016546879568225980636295312958082866554916714248978);
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        _delay(2);
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        this.deloop (836088442,300439563);
        this.convertFees();
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        echidna_ERC4626_ACTIONS_INVARIANT();
    }

    function test_I_INVARIANT_A() public {//PASS
        this.setInterestFee(101);
        echidna_I_INVARIANT();
    }

    function test_BM_INVARIANT_J() public {//PASS
        this.enableController(1033858464367648524212725884548716808308461431737128);
        this.setPrice(1174714766772749990658310097450526057892467243599336542, 1);
        this.loop(1,469651657411072073720922885808663968187985709);
        _delay(1);
        this.transferFromTo(0,0,0);
        echidna_BM_INVARIANT();
    }

    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}

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

    function test_BM_INVARIANT_O() public setup {
        this.depositToActor(20,93704952709166092675833692626070333629207815095066323987818791); 
        console.log("Actor: ", address(actor));
        this.enableController(3388611185579509790345271144155567529519710816754010133488659);
        this.setPrice(82722273493907026195652355382983934173897749054150317695866107075,1);
        console.log("Balance before: ", eTST.balanceOf(address(actor)));
        console.log("Debt before: ", eTST.debtOf(address(actor)));
        assetTST.burn(address(actor), assetTST.balanceOf(address(actor)));
        //this.borrowTo(1,476485543921707036124785589083935854038465196552);
        this.borrowTo(1,476485543921707036124785589083935854038465196552);
        this.borrowTo(15,476485543921707036124785589083935854038465196552);
        console.log("Balance after: ", eTST.balanceOf(address(actor)));
        console.log("Debt after: ", eTST.debtOf(address(actor)));
        echidna_BM_INVARIANT();
    }

    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}

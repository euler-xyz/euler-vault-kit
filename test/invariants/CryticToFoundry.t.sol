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

    function test_2TM_INVARIANT_C() public {//@audit-issue accumulatedFees is not being substracted from totalShares 
        this.enableController(2407062037475558912132939306295090);
        this.setPrice(203119967011525001828670166106715953503737,1);
        this.loop(1716,3708107580021407217882746540472109923629499262);
        _delay(118148);
        console.log("TotalSupply before: ", eTST.totalSupply());
        console.log("Accumulated Fees before: ", eTST.accumulatedFees());
        console.log("Extra balance: ", eTST.balanceOf(feeReceiver));
        echidna_TM_INVARIANT();

        console.log("              ");
        this.convertFees();
        console.log("TotalSupply after: ", eTST.totalSupply());
        console.log("Accumulated Fees after: ", eTST.accumulatedFees());
        console.log("Extra balance: ", eTST.balanceOf(feeReceiver));
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

    function test_BM_INVARIANT_A() public {//@audit-issue totalborrows invariant totalborrows carries more errors than per user balances
        _setUpActor(USER1);
        this.enableController(7940019329826366144274892142031768413507269414922630);
        this.setPrice(12009255528033600768137352216945045496365266793106593130770692883,1);
        this.loop(5430,659532459992408855116845120804223722874433054788209032745);
        _delay(332369);
        this.depositToActor(1524785993,1524785993);
        _delay(82671);
        this.assert_BM_INVARIANT_P();
        _delay(490448);
        this.mintToActor(1524785991,72575852986778215607110400910673949471717046724971908222700511120636941575644);
        _delay(400981);
        this.loop(4,0);
        _setUpActorAndDelay(USER3, 490446);
        this.disableControllerEVC(4370000);
        _setUpActorAndDelay(USER2, 512439);
        this.enableController(102991989108340896551270454655633010503448692163196646248725502583928854030805);
        _setUpActorAndDelay(USER3, 209930);
        this.borrowTo(21028135602513008682821171176143464055024276400678491579252791761338174084724,1524785992);
        _setUpActorAndDelay(USER1, 195123);
        this.disableBalanceForwarder();
        _setUpActorAndDelay(USER2, 100835);
        this.deloop(710,1524785992);
        _setUpActorAndDelay(USER2, 554465);
        this.withdraw(1524785993,0x492934308E98b590A626666B703A6dDf2120e85e);
        _setUpActorAndDelay(USER1, 24867);
        this.disableController();
        _setUpActorAndDelay(USER2, 361136);
        this.assert_BM_INVARIANT_P();
        _setUpActorAndDelay(USER1, 318197);
        this.disableController();
        _setUpActorAndDelay(USER1, 525476);
        this.approveTo(16869701013840301885380578357003794410242769734611639233528038245721131945253,10750826050293383041403999232338275642928888503893609432871664254603466977036);
        _setUpActorAndDelay(USER3, 117472);
        this.assert_BM_INVARIANT_N(1524785991);
        _setUpActorAndDelay(USER1, 275394);
        this.transferTo(1524785992,100196118046266658808320432975604017947824572508340007290653593633155865929931);
        _setUpActorAndDelay(USER3, 444463);
        this.disableController();
        _delay(361136);
        this.loop(4369999,138);
        _setUpActorAndDelay(USER1, 322247);
        this.disableCollateral(28390124907692794444539903006113767659433967837494470758618599764096921962498);
        _setUpActorAndDelay(USER3, 344203);
        this.loop(25429068410937927037543597849662629991331999066424093982753573180248239412249,4370000);
        _setUpActorAndDelay(USER2, 206186);
        this.loop(240,88375704015286133509148250866188404173444947300725240610116737539495058682202);
        _delay(521319);
        this.assert_BM_INVARIANT_N(0);
        _setUpActorAndDelay(USER3, 436727);
        this.enableCollateral(47563668076352632661547949096919334530300287099613969394302468802865162579994);
        _setUpActorAndDelay(USER2, 436727);
        this.reorderCollaterals(66962781791061653633752677216524320273559542393031461356195501353847440318709,71,191);
        _setUpActorAndDelay(USER3, 444463);
        this.disableController();
        _setUpActorAndDelay(USER1, 569114);
        this.assert_BM_INVARIANT_N(0);
        _setUpActorAndDelay(USER3, 277232);
        this.setPrice(115792089237316195423570985008687907853269984665640564039457584007913129639935,654231);
        _setUpActorAndDelay(USER2, 522178);
        this.redeem(4370000,0x385b2E03433C816DeF636278Fb600ecd056B0e8d);
        _setUpActorAndDelay(USER2, 511822);
        this.depositToActor(1524785992,260);
        _setUpActorAndDelay(USER1, 150273);
        this.convertFees();

        console.log("##################################################");

        console.log("Total borrows: ", eTST.totalBorrows());
        console.log("Debt of borrower: ", eTST.debtOf(actorAddresses[0]));
        console.log("Inerest Accumulator: ", eTST.interestAccumulator());
        console.log("Interest Accumulator per user: ", eTST.getUserInterestAccumulator(actorAddresses[0]));
 
        _setUpActorAndDelay(USER3, 526194);
        this.setDebtSocialization(true);

        console.log("Total borrows: ", eTST.totalBorrows());
        console.log("Debt of borrower: ", eTST.debtOf(actorAddresses[0]));
        console.log("Inerest Accumulator: ", eTST.interestAccumulator());
        console.log("Interest Accumulator per user: ", eTST.getUserInterestAccumulator(actorAddresses[0]));
 

        echidna_BM_INVARIANT();
    }

    function test_BASE_INVARIANT() public {// PASS
        assert_BASE_INVARIANT_B();
    }

    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}

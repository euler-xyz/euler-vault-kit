// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Errors} from "src/EVault/shared/Errors.sol";

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

    function test_BM_INVARIANT_O_ROUNDING() public {
        // PASS
        this.depositToActor(400, 93704952709166092675833692626070333629207815095066323987818791);
        console.log("Actor: ", address(actor));
        this.enableController(3388611185579509790345271144155567529519710816754010133488659);
        this.setPrice(82722273493907026195652355382983934173897749054150317695866107075, 0.9 ether);
        (uint256 collateralValue, uint256 liabilityValue) = _getAccountLiquidity(address(actor), false);
        console.log("Collateral Value: ", collateralValue);
        console.log("Liability Value: ", liabilityValue);
        console.log("Balance before: ", eTST.balanceOf(address(actor)));
        console.log("Debt before: ", eTST.debtOf(address(actor)));
        assetTST.burn(address(actor), assetTST.balanceOf(address(actor)));
        this.borrowTo(1, 476485543921707036124785589083935854038465196552);

        console.log("Total debt: ", eTST.totalBorrows());
        echidna_BM_INVARIANT();
    }

    function test_TM_INVARIANT_A() public {
        //PASS
        this.setPrice(0, 1);
        this.enableController(955302625856880925658809642386118260561143748);
        this.loop(4, 0);
        assert_TM_INVARIANT_A();
    }

    function test_TM_INVARIANT_C() public {
        //PASS
        this.enableController(7940019329826366144274892142031768413507269414922630);
        this.setPrice(12009255528033600768137352216945045496365266793106593130770692883, 1);
        this.loop(5430, 659532459992408855116845120804223722874433054788209032745);
        _delay(36473);
        console.log("BEFORE");
        this.transferFromTo(0, 66989060828690, 0);
        console.log("AFTER");

        console.log("Accumulated Fees: ", eTST.accumulatedFees());
        echidna_TM_INVARIANT();
    }

    function test_2TM_INVARIANT_C() public {
        // PASS
        this.enableController(2407062037475558912132939306295090);
        this.setPrice(203119967011525001828670166106715953503737, 1);
        this.loop(1716, 3708107580021407217882746540472109923629499262);
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

    function test_ERC4626_ACTIONS_INVARIANT() public {
        // PASS
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        this.enableController(7301099788150748633707767049393606426279241562950386710103457664483);
        this.setPrice(4386488222306922885577240690251822105318053011780346557732883264202, 1);
        this.loop(864261200, 42413089974244492524697016546879568225980636295312958082866554916714248978);
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        _delay(2);
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        this.deloop(836088442, 300439563);
        this.convertFees();
        console.log("TotalAssets: ", eTST.totalAssets());
        console.log("TotalShares", eTST.totalSupply());
        echidna_ERC4626_ACTIONS_INVARIANT();
    }

    function test_I_INVARIANT_A() public {
        vm.expectRevert(Errors.E_BadFee.selector);
        this.setInterestFee(101);
        echidna_I_INVARIANT();
    }

    function test_BM_INVARIANT_J() public {
        //PASS
        this.enableController(1033858464367648524212725884548716808308461431737128);
        this.setPrice(1174714766772749990658310097450526057892467243599336542, 1);
        this.loop(1, 469651657411072073720922885808663968187985709);
        _delay(1);
        this.transferFromTo(0, 0, 0);
        echidna_BM_INVARIANT();
    }

    function test_BM_INVARIANT_A() public {
        // PASS
        _setUpActor(USER1);
        this.enableController(7940019329826366144274892142031768413507269414922630);
        this.setPrice(12009255528033600768137352216945045496365266793106593130770692883, 1);
        this.loop(5430, 659532459992408855116845120804223722874433054788209032745);
        _delay(332369);
        this.depositToActor(1524785993, 1524785993);
        _delay(82671);
        this.assert_BM_INVARIANT_P();
        _delay(490448);
        this.mintToActor(1524785991, 72575852986778215607110400910673949471717046724971908222700511120636941575644);
        _delay(400981);
        this.loop(4, 0);
        _setUpActorAndDelay(USER3, 490446);
        this.disableControllerEVC(4370000);
        _setUpActorAndDelay(USER2, 512439);
        this.enableController(102991989108340896551270454655633010503448692163196646248725502583928854030805);
        _setUpActorAndDelay(USER3, 209930);
        this.borrowTo(21028135602513008682821171176143464055024276400678491579252791761338174084724, 1524785992);
        _setUpActorAndDelay(USER1, 195123);
        this.disableBalanceForwarder();
        _setUpActorAndDelay(USER2, 100835);
        this.deloop(710, 1524785992);
        _setUpActorAndDelay(USER2, 554465);
        this.withdraw(1524785993, 0x492934308E98b590A626666B703A6dDf2120e85e);
        _setUpActorAndDelay(USER1, 24867);
        this.disableController();
        _setUpActorAndDelay(USER2, 361136);
        this.assert_BM_INVARIANT_P();
        _setUpActorAndDelay(USER1, 318197);
        this.disableController();
        _setUpActorAndDelay(USER1, 525476);
        this.approveTo(
            16869701013840301885380578357003794410242769734611639233528038245721131945253,
            10750826050293383041403999232338275642928888503893609432871664254603466977036
        );
        _setUpActorAndDelay(USER3, 117472);
        this.assert_BM_INVARIANT_N(1524785991);
        _setUpActorAndDelay(USER1, 275394);
        this.transferTo(1524785992, 100196118046266658808320432975604017947824572508340007290653593633155865929931);
        _setUpActorAndDelay(USER3, 444463);
        this.disableController();
        _delay(361136);
        this.loop(4369999, 138);
        _setUpActorAndDelay(USER1, 322247);
        this.disableCollateral(28390124907692794444539903006113767659433967837494470758618599764096921962498);
        _setUpActorAndDelay(USER3, 344203);
        this.loop(25429068410937927037543597849662629991331999066424093982753573180248239412249, 4370000);
        _setUpActorAndDelay(USER2, 206186);
        this.loop(240, 88375704015286133509148250866188404173444947300725240610116737539495058682202);
        _delay(521319);
        this.assert_BM_INVARIANT_N(0);
        _setUpActorAndDelay(USER3, 436727);
        this.enableCollateral(47563668076352632661547949096919334530300287099613969394302468802865162579994);
        _setUpActorAndDelay(USER2, 436727);
        this.reorderCollaterals(66962781791061653633752677216524320273559542393031461356195501353847440318709, 71, 191);
        _setUpActorAndDelay(USER3, 444463);
        this.disableController();
        _setUpActorAndDelay(USER1, 569114);
        this.assert_BM_INVARIANT_N(0);
        _setUpActorAndDelay(USER3, 277232);
        this.setPrice(115792089237316195423570985008687907853269984665640564039457584007913129639935, 654231);
        _setUpActorAndDelay(USER2, 522178);
        this.redeem(4370000, 0x385b2E03433C816DeF636278Fb600ecd056B0e8d);
        _setUpActorAndDelay(USER2, 511822);
        this.depositToActor(1524785992, 260);
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

    function test_BM_INVARIANT_G() public {
        // PASS
        this.assert_BM_INVARIANT_G();
    }

    function test_assert_BM_INVARIANT_N() public {
        // PASS
        this.enableController(1353974430231330282141559749);
        this.setPrice(0, 1);
        this.loop(1, 27285321264845944093387872171310745136030);
        _delay(1);
        this.assert_BM_INVARIANT_N(1);
    }

    function test_BASE_INVARIANT1() public {
        // PASS
        assert_BASE_INVARIANT_B();
    }

    function test_TM_INVARIANT_B() public {
        // PASS
        _setUpBlockAndActor(23863, USER2);
        this.mintToActor(3, 2517);
        _setUpBlockAndActor(77040, USER1);
        this.enableController(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        _setUpBlockAndActor(115661, USER1);
        this.assert_BM_INVARIANT_G();
        echidna_TM_INVARIANT();
    }

    function test_TM_INVARIANT_A2() public {
        // PASS
        _setUpBlockAndActor(24293, USER1);
        this.depositToActor(464, 95416406916653671687163906321353417359071456765389709042486010813678577176823);
        _setUpBlockAndActor(47163, USER2);
        this.enableController(115792089237316195423570889601861022891927484329094684320502060868636724166656);
        _setUpBlockAndActor(47163, USER2);
        this.assert_BM_INVARIANT_G();
        echidna_TM_INVARIANT();
    }

    function test_TM_INVARIANT_B2() public {
        // PASS
        _setUpBlockAndActor(31532, USER3);
        this.mintToActor(134, 38950093316855029701707435728471143612397649181229202547446285813971152397387);
        _setUpBlockAndActor(31532, USER2);
        this.deloop(129, 208);
        echidna_TM_INVARIANT();
    }

    function test_TM_INVARIANT2() public {
        _setUpBlockAndActor(15941, USER2);
        this.enableController(65987143226213886175183319384713235742055287956171498516718399508227226907932);
        this.setPrice(536074487209797201035050856521703277098472151229817426108599925962560785369, 4);
        _setUpBlockAndActor(25252, USER2);
        this.loop(19050045013, 115792089237316195423570985008687907853269984665640564039457584007913129634936);
        _setUpBlockAndActor(56461, USER2);
        this.setDebtSocialization(true);
        _setUpBlockAndActor(56461, USER3);
        this.convertFees();
        echidna_TM_INVARIANT();
    }

    function test_VM_INVARIANT1() public {
        // PASS
        _setUpBlockAndActor(15941, USER2);
        this.enableController(65987143226213886175183319384713235742055287956171498516718399508227226907932);
        this.setPrice(536074487209797201035050856521703277098472151229817426108599925962560785369, 4);
        _setUpBlockAndActor(60909, USER2);
        this.loop(17, 129);
        _setUpBlockAndActor(76974, USER2);
        this.assert_BM_INVARIANT_P();
        _setUpBlockAndActor(83000, USER1);
        this.enableCollateral(115792089237316195423570985008687907853269984665640564039457584007913129639917);
        _setUpBlockAndActor(83200, USER1);
        this.assert_BM_INVARIANT_G();
        echidna_VM_INVARIANT();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REVISION 2                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_BASE_INVARIANT2() public {
        // PASS
        _setUpBlockAndActor(25742, USER3);
        this.mintToActor(
            457584007913129639927, 115792089237316195423570985008687907853269984665640564039457584007913129639768
        );
        echidna_BASE_INVARIANT();
    }

    function test_BM_INVARIANT3() public {
        // PASS
        _setUpBlockAndActor(12272, USER1);
        this.setLTV(113884487589860002952951511119799819009743936658790969442180828775288854748777, 40, 0);
        _setUpActor(USER2);
        this.enableCollateral(61359321533616670090464847470919828791539490567821399398610379891777185889295);
        _setUpBlockAndActor(12281, USER2);
        this.enableController(21176976167352574707055888237761398779945424238152129202553051033751536223044);
        _setUpBlockAndActor(13460, USER1);
        this.setPrice(47623990069036807621229864744315512880511717210498659943999994201483491729478, 1 ether);
        _setUpBlockAndActor(42391, USER2);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            console.log("-----------------");
            console.log("Actor: ", i);
            console.log("-----------------");
            console.log("Debt of: ", eTST.debtOf(actorAddresses[i]));
            console.log("Balance of: ", eTST.balanceOf(actorAddresses[i]));
            (uint256 collateralValue, uint256 liabilityValue) = _getAccountLiquidity(address(actor), false);
            console.log("Collateral Value: ", collateralValue);
            console.log("Liability Value: ", liabilityValue);
            console.log("-----------------");
        }
        this.loop(6656, 115792089237316195423570985008240606102015950752194670824766749710982583118548);
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            console.log("-----------------");
            console.log("Actor: ", i);
            console.log("-----------------");
            console.log("Debt of: ", eTST.debtOf(actorAddresses[i]));
            console.log("Balance of: ", eTST.balanceOf(actorAddresses[i]));
            (uint256 collateralValue, uint256 liabilityValue) = _getAccountLiquidity(address(actor), false);
            console.log("Collateral Value: ", collateralValue);
            console.log("Liability Value: ", liabilityValue);
            console.log("-----------------");
        }
        echidna_BM_INVARIANT();
    }

    function test_LM_INVARIANT_B() public {
        // PASS
        _setUpBlockAndActor(24253, USER3);
        this.setDebtSocialization(false);
        this.mintToActor(40, 115792089237316195423570985008687907853269984665640564039457584007911240072655);
    }

    function test_BM_INVARIANT5() public {
        // PASS
        _setUpBlockAndActor(12272, USER1);
        this.setLTV(113884487589860002952951511119799819009743936658790969442180828775288854748777, 40, 0);
        _setUpActor(USER2);
        this.enableCollateral(61359321533616670090464847470919828791539490567821399398610379891777185889295);
        _setUpBlockAndActor(12281, USER2);
        this.enableController(21176976167352574707055888237761398779945424238152129202553051033751536223044);
        _setUpBlockAndActor(13460, USER1);
        this.setPrice(47623990069036807621229864744315512880511717210498659943999994201483491729478, 100);
        _setUpBlockAndActor(42391, USER2);
        this.loop(6656, 115792089237316195423570985008240606102015950752194670824766749710982583118548);
        echidna_BM_INVARIANT();
    }

    function test_BM_INVARIANT4() public {
        // PASS
        _setUpBlockAndActor(12272, USER1);
        this.setLTV(113884487589860002952951511119799819009743936658790969442180828775288854748777, 40, 0);
        _setUpActor(USER2);
        this.enableCollateral(61359321533616670090464847470919828791539490567821399398610379891777185889295);
        _setUpBlockAndActor(12281, USER2);
        this.enableController(21176976167352574707055888237761398779945424238152129202553051033751536223044);
        _setUpBlockAndActor(13460, USER1);
        this.setPrice(47623990069036807621229864744315512880511717210498659943999994201483491729478, 100);
        _setUpActor(USER2);
        this.loop(9, 115792089237316195423570985008240606102015950752194670824766749710982583118484);
        echidna_BM_INVARIANT();
    }

    function test_BM_INVARIANT6() public {
        // PASS
        this.enableController(468322383632155574862945881956174631649161871295786712111360326257);
        this.setPrice(726828870758264026864714326152620643619927705875320304690180955674, 11);
        this.enableCollateral(15111);
        this.setLTV(3456147621700665956033923462455625826034483547574136595412029999975872, 1, 0);
        this.depositToActor(1, 0);
        this.borrowTo(1, 304818507942225219676445155333052560942359548832832651640621508);
        echidna_BM_INVARIANT();
    }

    function test_TM_INVARIANT_B1() public {
        // PASS
        this.setLTV(72646444105010896140249531445510794379335059401176316902940832566730525333, 1, 0);
        this.enableController(76727920995346075805986660253082611215461573362058062359387778966104779);
        this.setPrice(18274017484987942229281406421604794173269384380531735656284002919498327, 31);
        this.depositToActor(102086320, 162507);
        this.enableCollateral(106093357538464973839764110958525094882282094641942554217387777389198);
        this.borrowTo(94684478, 359189140925596108270502857324445830015961981690427474212615823204087831);
        _delay(1062);
        this.loop(30806, 260);
        echidna_TM_INVARIANT();
    }

    function test_echidna_VM_INVARIANT_C1() public {
        //@audit-issue totalSupply == 0 !=> totalAssets == 0
        vm.skip(true);
        this.setLTV(161537350060562470698068789285938700031433026666990925968846691117425, 1, 0);
        this.mintToActor(2, 0);
        this.setPrice(15141093523755052381928072114906306924899029026721034293540167406168436, 12);
        this.enableController(0);

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        this.enableCollateral(4565920164825741688803703057878134831253824142353322861254361347742);
        this.borrowTo(1, 0);

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        console.log("balanceOf: ", eTST.balanceOf(address(actor)));
        console.log("debtOf: ", eTST.debtOf(address(actor)));

        _delay(525);

        console.log("----------");

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        console.log("balanceOf: ", eTST.balanceOf(address(actor)));
        console.log("debtOf: ", eTST.debtOf(address(actor)));

        console.log("----------");

        this.deloop(2, 0);

        console.log("----------");

        console.log("balanceOf: ", eTST.balanceOf(address(actor)));
        console.log("debtOf: ", eTST.debtOf(address(actor)));

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        console.log("----------");

        /*         this.loop(2,0);

        console.log("----------");

        console.log("balanceOf: ", eTST.balanceOf(address(actor)));
        console.log("debtOf: ", eTST.debtOf(address(actor)));

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        console.log("----------");

        this.deloop(3,0);

        console.log("----------");

        console.log("balanceOf: ", eTST.balanceOf(address(actor)));
        console.log("debtOf: ", eTST.debtOf(address(actor)));

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalAssets());

        console.log("----------"); */

        assert_VM_INVARIANT_C();
    }

    function test_liquidate_bug() public {
        _setUpActorAndDelay(USER3, 297507);
        this.setLTV(115792089237316195423570985008687907853269984665640564039457584007913129639935, 433, 0);
        _setUpActor(USER1);
        this.enableController(1524785991);
        _setUpActorAndDelay(USER1, 439556);
        this.enableCollateral(217905055956562793374063556811130300111285293815122069343455239377127312);
        _setUpActorAndDelay(USER3, 566039);
        this.enableCollateral(29);
        _setUpActorAndDelay(USER3, 209930);
        this.enableController(1524785993);
        _delay(271957);
        this.liquidate(2848675, 0, 512882652);
    }

    function test_depositToActor_bug() public {
        // PASS
        this.setPrice(0, 1);
        this.enableController(14915426056955909235945450448249579464926501795441141063845034703);
        this.setLTV(1804231840195618435650555517191418148400545023790587635103902141215022596, 10, 0);
        this.enableCollateral(10191944320714549829463304788724380680435294253545712225788598892553430);
        this.loop(68702, 6778451088499331638632504780946916120996051624015916139354432081940282166);
        this.setDebtSocialization(false);
        _delay(6847);
        this.assert_BM_INVARIANT_P();
        this.assert_BM_INVARIANT_G();
        this.depositToActor(2, 77621934147193536615522822188877143744675248208047599569948726783);
    }

    function test_VM_INVARIANT5() public {
        vm.skip(true);
        this.setLTV(22366818273602115439851901107761977982005180121616743889078085180117, 1, 0);
        this.mintToActor(1, 0);
        this.enableCollateral(0);
        this.setPrice(167287376704962748125159831258059871163051958738722404000304447051, 11);
        this.enableController(0);
        this.borrowTo(1, 0);
        _delay(1);
        this.assert_BM_INVARIANT_P();
        console.log("totalAssets: ", eTST.totalAssets());
        console.log("totalSupply: ", eTST.totalSupply());
        this.assert_BM_INVARIANT_G();
        console.log("totalAssets: ", eTST.totalAssets());
        console.log("totalSupply: ", eTST.totalSupply());
        echidna_VM_INVARIANT();
    }

    function test_BM_INVARIANT2() public {
        this.setLTV(4928164140911258518180007983958125974735619848025477191374701, 1, 0);
        this.enableController(856923007128263309132381892881869186587227104865745);
        this.setPrice(32481800912426910820104697344689416508300540223088706165503630635883, 10);
        this.enableCollateral(6856418744684697184782054554105384170694608997133);
        this.loop(1, 0);
        echidna_BM_INVARIANT();
    }

    function test_BM_INVARIANT7() public {
        this.setLTV(1108761414529882035672596488633488862111302583, 1, 0);
        this.enableController(29103678329368710051385488);
        this.setPrice(40675291513600242204969450702211991997576963878828186222022, 10);
        this.enableCollateral(658636526787455111532741);
        this.loop(1, 0);
        echidna_BM_INVARIANT();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

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

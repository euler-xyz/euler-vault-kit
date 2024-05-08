// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Errors} from "src/EVault/shared/Errors.sol";

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup, DeployPermit2} from "./Setup.t.sol";

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
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_TM_INVARIANT_A1() public {
        //PASS
        this.setPrice(0, 1);
        this.enableController(955302625856880925658809642386118260561143748);
        this.loop(4, 0);
        assert_TM_INVARIANT_A();
    }

    function test_TM_INVARIANT_C1() public {
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

    function test_TM_INVARIANT_C2() public {
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
        // PASS
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

    function test_BM_INVARIANT_G() public {
        // PASS
        this.assert_BM_INVARIANT_G();
    }

    function test_BM_INVARIANT_N1() public {
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
        // PASS
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
    //                                    INVARIANTS REVISION 2                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_BASE_INVARIANT2() public {
        // PASS
        _setUpBlockAndActor(25742, USER3);
        this.mintToActor(
            457584007913129639927, 115792089237316195423570985008687907853269984665640564039457584007913129639768
        );
        echidna_BASE_INVARIANT();
    }

    function test_BM_INVARIANT1() public {
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

    function test_BM_INVARIANT2() public {
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

    function test_BM_INVARIANT3() public {
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

    function test_BM_INVARIANT4() public {
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

    function test_liquidate_bug() public {
        // PASS
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

    function test_VM_INVARIANT_C() public {
        vm.skip(true); // TODO remove skip after fixing issue 3 test_echidna_VM_INVARIANT_C
        // PASS
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
        assert_VM_INVARIANT_C();
    }

    function test_BM_INVARIANT5() public {
        this.setLTV(4928164140911258518180007983958125974735619848025477191374701, 1, 0);
        this.enableController(856923007128263309132381892881869186587227104865745);
        this.setPrice(32481800912426910820104697344689416508300540223088706165503630635883, 10);
        this.enableCollateral(6856418744684697184782054554105384170694608997133);
        this.loop(1, 0);
        echidna_BM_INVARIANT();
    }

    function test_BM_INVARIANT6() public {
        // PASS
        this.setLTV(1108761414529882035672596488633488862111302583, 1, 0);
        this.enableController(29103678329368710051385488);
        this.setPrice(40675291513600242204969450702211991997576963878828186222022, 10);
        this.enableCollateral(658636526787455111532741);
        this.loop(1, 0);
        echidna_BM_INVARIANT();
    }

    function test_TM_INVARIANT3() public {
        this.enableCollateral(1492406989896342662931682233968348948879768078487071317507267603313218845);
        this.setPrice(47316989100111836776239614391395336110230084366532349161434951144018048518882, 265922230);
        this.enableController(4676793);
        this.setLTV(1102827347149377822286214252767622168405969142467800685291673001117802659100, 24, 0);
        this.loop(1083615, 8350218887871273119285207758028153871039181143352271750618863929154528834074);
        _delay(361136);
        this.deloop(56158494, 204097);
        _delay(31117);
        echidna_TM_INVARIANT();
        this.assert_BM_INVARIANT_N(673660);
        echidna_TM_INVARIANT();
    }

    function test_borrowTo() public {
        // PASS
        //1
        _setUpActorAndDelay(USER2, 490446);
        this.enableController(23590522885039183041260746068517665478516692400896843183204467951556228246910);
        //2
        _setUpActorAndDelay(USER3, 512439);
        this.setAccountOperator(
            37422360797388659926273355959020941020748907573461287313227549042729911993476, 4369999, true
        );
        //3
        _setUpActorAndDelay(USER3, 522178);
        this.setLTV(115792089237316195423570985008687907853269984665640564039457584007913129639935, 433, 0);
        //4
        _setUpActorAndDelay(USER1, 112444);
        this.setPrice(40914056993793104788315297825773571013627186118417779249529381785127196877865, 1524785993);
        //5
        _setUpActorAndDelay(USER2, 50417);
        this.enableCollateral(70149630531852007137311311802119342861327375032275365439622858589719945919642);
        //6
        _setUpActorAndDelay(USER2, 322247);
        this.loop(1524785993, 69916723412968911114943808841412407707361196266713409567884568339007290731840);
        //7
        _setUpActorAndDelay(USER2, 338920);
        this.clearLTV(71009432250145470994451289820969979484524987801264257785324961952258666024395);
        //8
        _setUpActorAndDelay(USER2, 195123);
        this.enableController(33571248811029009915959855386862679789529315975700137835709736018357409480975);
        //9
        _setUpActorAndDelay(USER3, 166184);
        this.borrowTo(0, 33442568265909725660958228071592061126568592178990140996663847638550934975995);
    }

    function test_assert_BM_INVARIANT_G() public {
        // PASS
        this.mintToActor(1003312401234322606480, 2729841043762097358256378677021606155986323805459762004095238001675780);
        this.assert_BM_INVARIANT_G();
    }

    function test_echidna_BM_INVARIANT() public {
        // PASS
        actor = actors[USER1];
        this.enableCollateral(922913102519023513638263568693184007882890256999730018500051464702692);
        this.enableController(87);
        this.setPrice(721910648172829791324101465922639417876998663108006437336366166873928, 71);
        this.setLTV(526509992928461810641826760970311199485049830666012555826501590, 1, 0);
        this.loop(1, 21422454030655277497926666454484821609147656300902255824816571);
        echidna_BM_INVARIANT();
    }

    function test_borrowToAssertion() public {
        // PASS
        // 1
        _setUpActorAndDelay(USER3, 318197);
        this.enableCollateral(95689745852354391340937265830421619118782297678957238918042131368407047793867);

        // 2
        this.setPrice(115792089237316195423570985008687907853269984665640564039457584007913129639935, 93);

        // 3
        _setUpActorAndDelay(USER1, 332610);
        this.enableController(115437764919907105833673970910567671210741252898697804025668519793068961055942);

        // 4
        _setUpActorAndDelay(USER3, 45142);
        this.enableController(1524785993);

        // 5
        _setUpActorAndDelay(USER1, 33605);
        this.setLTV(48927917892407722847764904249508727881508752237343775862718029767550782933820, 550, 0);

        // 6
        _setUpActorAndDelay(USER3, 292304);
        this.loop(4369999, 18373863112472169334002883060878227681949138131067182781611637989977690818863);

        // 7
        _setUpActorAndDelay(USER2, 490448);
        this.setPrice(
            115792089237316195423570985008687907853269984665640564039457584007913129639934,
            485773995947666375448672588909981360252274712590730398973918012950
        );

        // 8
        _setUpActorAndDelay(USER3, 585013);
        this.setLTV(15283710050316403288893490315391161676431816099734250238867643747212256114164, 0, 6084195);

        // 9
        _setUpActorAndDelay(USER1, 41445142736);

        console.log("Debt of actor: ", eTST.debtOf(address(actor)));
        (uint256 collateralValue,) = _getAccountLiquidity(address(actor), false);
        console.log("Collateral value: ", collateralValue);

        console.log("Cash: ", eTST.cash());

        this.borrowTo(115792089237316195423570985008687907853269984665640564039457584007913129639935, 1524785993);

        console.log("Debt of actor: ", eTST.debtOf(address(actor)));
        (collateralValue,) = _getAccountLiquidity(address(actor), false);
        console.log("Collateral value: ", collateralValue);

        console.log("Cash: ", eTST.cash());
    }

    function test_liquidate_assertion() public {
        // 1
        _setUpActorAndDelay(USER1, 49735);
        this.enableController(4370001);

        // 2
        _delay(419861);
        this.enableCollateral(115792089237316195423570985008687907853269984665640564039457584007913129639935);

        // 3
        _setUpActor(USER2);
        this.enableCollateral(61638596643366077731523903617284399414995672784229563021134763223083425246563);

        // 4
        _setUpActorAndDelay(USER1, 526194);
        this.setPrice(72787926378501882229800261391272478436023613997891825535870537839083931073677, 1524785992);

        // 5
        _delay(33605);
        this.setLTV(48111038919057540783612655871084361062763944857885077545848014857015966498053, 550, 0);

        // 6
        _setUpActorAndDelay(USER2, 519847);
        this.enableController(38655521791569740740590194885665571827737110912262165236043545881387611913498);

        // 7
        _setUpActor(USER1);
        this.loop(1524785993, 68453602506955980124600356209223381080227097675627752130927574903461825946066);

        // 8
        _setUpActor(USER2);
        this.liquidate(0, 0, 34535886362188912658895677728833997361132855974424654148329846763788584695072);
    }

    function test_BM_INVARIANT_A() public {
        vm.skip(true);
        // 1
        _setUpActorAndDelay(USER3, 318197);
        this.enableCollateral(95689745852354391340937265830421619118782297678957238918042131368407047793867);

        // 2
        this.setPrice(115792089237316195423570985008687907853269984665640564039457584007913129639935, 93);

        // 3
        _setUpActorAndDelay(USER1, 332610);
        this.enableController(115437764919907105833673970910567671210741252898697804025668519793068961055942);

        // 4
        _delay(419861);
        this.enableCollateral(115792089237316195423570985008687907853269984665640564039457584007913129639935);

        // 5
        _setUpActorAndDelay(USER3, 45142);
        this.enableController(1524785993);

        // 6
        _setUpActorAndDelay(USER1, 33605);
        this.setLTV(48927917892407722847764904249508727881508752237343775862718029767550782933820, 550, 0);

        // 7
        _setUpActorAndDelay(USER3, 292304);
        this.loop(4369999, 18373863112472169334002883060878227681949138131067182781611637989977690818863);

        // 8
        _setUpActorAndDelay(USER3, 127251);
        this.enableBalanceForwarder();

        // 9
        _setUpActorAndDelay(USER1, 522178);
        this.assert_ERC4626_roundtrip_invariantB(0);

        // 10
        _setUpActorAndDelay(USER1, 379552);
        this.setAccountOperator(1524785992, 1524785991, true);

        // 11
        _setUpActorAndDelay(USER3, 384809);
        this.loop(
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            30238618815296766323238823187155304801252470144407526210769925532839114580537
        );

        // 12
        _setUpActorAndDelay(USER3, 82672);
        this.disableBalanceForwarder();

        // 13
        _setUpActorAndDelay(USER2, 521319);
        this.disableBalanceForwarder();

        // 14
        _setUpActorAndDelay(USER2, 412373);
        this.transferFromTo(
            74709723365675866520198702262748757545228512921032297518487175904196653013110,
            4370001,
            53945530038175606090290185328356412792167504165683508732428637599212900338806
        );

        // 15
        _setUpActorAndDelay(USER2, 82671);
        this.assert_ERC4626_roundtrip_invariantB(0);

        // 16
        _setUpActorAndDelay(USER3, 400981);
        this.setCaps(21140, 39689);

        // 17
        _setUpActorAndDelay(USER2, 376096);
        this.setAccountOperator(
            26702281703431794942818578993268324557852967740812877010255745010366730625764, 4370000, false
        );

        // 18
        _setUpActorAndDelay(USER1, 33605);
        this.depositToActor(1, 9593246964261939413659890356071148507434227185199157971153941);

        // 19
        _setUpActorAndDelay(USER2, 588255);
        this.setAccountOperator(
            29592031691392305345099686540778351143294516055365183986838557368259304598530, 1139, true
        );

        // 20
        _setUpActorAndDelay(USER3, 400981);
        this.depositToActor(0, 9593246964261939413659890356071148507434227185199157971153941);

        // 21
        _delay(512439);

        // 22
        _setUpActorAndDelay(USER3, 338920);
        this.enableCollateral(1492406989896342662931682233968348948879768078487071317507267603313218845);

        // 23
        _setUpActorAndDelay(USER3, 368220);
        this.touch();

        // 24
        _setUpActorAndDelay(USER1, 522178);
        this.disableControllerEVC(115792089237316195423570985008687907853269984665640564039457584007913129639935);

        // 25
        _setUpActorAndDelay(USER3, 50417);
        this.touch();

        // 26
        _setUpActorAndDelay(USER3, 566039);
        this.enableCollateral(1492406989896342662931682233968348948879768078487071317507267603313218845);

        // 27
        _setUpActorAndDelay(USER3, 172101);
        this.loop(1083615, 8350218887871273119285207758028153871039181143352271750618863929154528834074);

        // 28
        _delay(33271);

        // 29
        _setUpActorAndDelay(USER2, 512439);
        this.assert_ERC4626_roundtrip_invariantA(92481461);

        // 30
        _setUpActorAndDelay(USER2, 521319);
        this.requireAccountStatusCheck(115792089237316195423570985008687907853269984665640564039457584007913129639935);

        // 31
        _setUpActorAndDelay(USER3, 206186);
        this.reorderCollaterals(154785991, 255, 255);

        // 32
        _setUpActorAndDelay(USER3, 436727);
        this.disableController();

        // 33
        _setUpActorAndDelay(USER1, 569114);
        this.setAccountOperator(
            2460100706, 25606913327106858044600689617104190301347809270924118227424197241903364076640, false
        );

        // 34
        _setUpActorAndDelay(USER3, 401699);
        this.assert_BM_INVARIANT_G();

        // 35
        _setUpActorAndDelay(USER3, 73040);
        this.mintToActor(4369999, 104699655680504571352280589742913258906811444502893368443300689951814972136387);

        // 36
        _setUpActorAndDelay(USER1, 399660);
        this.deloop(56158494, 204097);

        // 37
        _setUpActorAndDelay(USER2, 127);
        this.disableController();

        // 38
        _setUpActorAndDelay(USER2, 401699);
        this.convertFees();

        // 39
        _setUpActorAndDelay(USER2, 43744);
        this.setPrice(35400180736537901162468777377101573555002144542251234306373318600995941965870, 1524785992);

        // 40
        _setUpActorAndDelay(USER3, 401699);
        this.setPrice(4370001, 4370000);

        // 41
        _setUpActorAndDelay(USER1, 360385);
        this.setPrice(47316989100111836776239614391395336110230084366532349161434951144018048518882, 265922230);

        // 42
        _setUpActorAndDelay(USER2, 438439);
        this.convertFees();

        // 43
        _setUpActorAndDelay(USER2, 353050);
        this.enableController(1524785993);

        // 44
        _setUpActorAndDelay(USER2, 225906);
        this.repayTo(
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            25353498197692747351122545399750766641940248826967067793249422328251844214571
        );

        // 45
        _setUpActorAndDelay(USER1, 12155);
        this.assert_BM_INVARIANT_N(673660);

        // 46
        _setUpActorAndDelay(USER2, 49735);
        this.deloop(56158494, 204097);

        // 47
        _setUpActorAndDelay(USER2, 271957);
        this.touch();

        console.log("Toral borrows: %s", eTST.totalBorrows());
        console.log("Debt of borrower: %s", eTST.debtOf(actorAddresses[0]));

        echidna_BM_INVARIANT();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   INVARIANTS REVISION 3                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_assert_BM_INVARIANT_P() public {
        // 1
        _setUpActorAndDelay(USER3, 318197);
        this.enableCollateral(2);

        // 2
        _setUpActorAndDelay(USER1, 332610);
        this.enableController(0);

        // 3
        _setUpActorAndDelay(USER1, 419861);
        this.enableCollateral(0);

        // 4
        _setUpActorAndDelay(USER3, 45142);
        this.enableController(2);

        // 5
        _setUpActorAndDelay(USER2, 82672);
        this.setPrice(76848675288217129596403145934243173824047724886450477154848028682077772742994, 1524785992);

        // 6
        _setUpActorAndDelay(USER1, 33605);
        this.setLTV(48927917892407722847764904249508727881508752237343775862718029767550782933820, 550, 0);

        // 7
        _setUpActorAndDelay(USER3, 292304);
        this.loop(4369999, 2);

        _setUpActorAndDelay(USER1, 4177);
        console.log("DebtOf: ", eTST.debtOf(address(actor)));

        this.assert_BM_INVARIANT_N(4370001);

        console.log("DebtOf: ", eTST.debtOf(address(actor)));

        (uint16 supplyCap, uint16 borrowCap) = eTST.caps();

        console.log("Supply Cap: ", supplyCap);
        console.log("Borrow Cap: ", borrowCap);

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalBorrows());

        _setUpActorAndDelay(USER1, 136394);
        this.setCaps(6080, 0);

        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalBorrows());

        _setUpActorAndDelay(USER3, 4414736);
        console.log("TotalSupply: ", eTST.totalSupply());
        console.log("TotalAssets: ", eTST.totalBorrows());
        console.log("Cash: ", eTST.cash());
        this.assert_BM_INVARIANT_P();
    }

    function test_BM_INVARIANT_N2() public {
        //1
        this.setPrice(0, 1);
        //2
        this.setLTV(7561741683078052557167807866265778731783825737315070859139285684127362297341, 11, 0);
        //3
        this.enableCollateral(7080277318487020457735061392069730290966959631234465923425796693418843001702);
        //4
        this.enableController(1167036);
        //5
        this.loop(304154, 0);
        //6
        this.assert_BM_INVARIANT_P();
        //7
        this.loop(355744493, 36696897707460454000555010489581781918967195767855418531121511051163383131);
        //8
        _delay(521319);
        this.transferTo(2175028710635044686948068638585391526952234117185290277440105557547, 79);
        //9
        _delay(40374);
        this.disableBalanceForwarder();
        //10
        this.loop(11269, 275590633595236244028395967495704060163744939232083057790727256046236601);
        //11
        this.assert_BM_INVARIANT_N(658970049);
    }

    function test_echidna_VM_INVARIANT_C() public {
        //@audit-issue 3. Dust assets can get stuck in the vault forever
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

        assert_VM_INVARIANT_C();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function getBytecode(address _contractAddress) internal view returns (bytes memory) {
        uint256 size;
        assembly {
            size := extcodesize(_contractAddress)
        }
        bytes memory bytecode = new bytes(size);
        assembly {
            extcodecopy(_contractAddress, add(bytecode, 0x20), 0, size)
        }
        return bytecode;
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

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase, EthereumVaultConnector} from "test/unit/evault/EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import "src/EVault/shared/Constants.sol";
import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Events.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

// If this address is installed, it should be able to set disabled ops
// Use a different address than the governor
// The pauseGuardian() accessor should return the currently installed pause guardian
// After pausing, trying to invoke the disabled ops should fail
// The pause guardian should be able to re-enable the ops (unpause)
// After re-enabling, the ops should start working again

contract Governance_PauseAndOps is EVaultTestBase {
    address notGovernor;
    address borrower;
    address depositor;
    uint256 constant MINT_AMOUNT = 100e18;

    function setUp() public override {
        super.setUp();
        notGovernor = makeAddr("notGovernor");
        borrower = makeAddr("borrower");
        depositor = makeAddr("depositor");
        // ----------------- Setup depositor -----------------
        vm.startPrank(depositor);
        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(MINT_AMOUNT, depositor);
        vm.stopPrank();
        vm.label(depositor, "DEPOSITOR");
        // ----------------- Setup borrower -----------------
        vm.startPrank(borrower);
        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(MINT_AMOUNT, borrower);
        vm.stopPrank();
        vm.label(borrower, "BORROWER");
        // ----------------- this is the pause guardian -----------------
        vm.label(address(this), "PAUSE_GUARDIAN/ADMIN");
    }

    function testFuzz_setDisabledOpsShouldFailIfNotGovernor(uint32 newDisabledOps) public {
        vm.prank(notGovernor);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setDisabledOps(newDisabledOps);
    }

    // disabled ops should fail if governor is not set
    function testFuzz_disabledOpsShouldFailIfGovernorNotSet(uint32 newDisabledOps) public {
        eTST.setPauseGuardian(address(0));
        vm.expectRevert(Errors.E_Unauthorized.selector);
        eTST.setDisabledOps(newDisabledOps);
    }

    function testFuzz_pauseGuardianShouldBeAbleToSetPauseGuardian(address newGovernor) public {
        eTST.setPauseGuardian(newGovernor);
        assertEq(eTST.pauseGuardian(), newGovernor);
    }

    function testFuzz_pauseGuardianShouldBeAbleToSetDisabledOps(uint32 newDisabledOps) public {
        eTST.setDisabledOps(newDisabledOps);
        assertEq(eTST.disabledOps(), newDisabledOps);
    }

    function testFuzz_disablingDepositOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        vm.assume(receiver != address(0));

        eTST.setDisabledOps(OP_DEPOSIT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(amount, receiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(depositor);
        eTST.deposit(amount, receiver);
    }

    function testFuzz_disablingMintOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        vm.assume(receiver != address(0));

        eTST.setDisabledOps(OP_MINT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(amount, receiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(depositor);
        eTST.mint(amount, receiver);
    }

    function testFuzz_disablingWithdrawOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner)
        public
    {
        amount = bound(amount, 1, MINT_AMOUNT);
        vm.assume(receiver != address(0));

        eTST.setDisabledOps(OP_WITHDRAW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.withdraw(amount, receiver, owner);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(depositor);
        eTST.withdraw(amount, receiver, depositor); // depositor should be able to withdraw
    }

    function testFuzz_disablingRedeemOpsShouldFailAfterDisabled(uint256 amount, address receiver, address owner)
        public
    {
        eTST.setDisabledOps(OP_REDEEM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(amount, receiver, owner);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(depositor);
        // type(uint256).max redeems all of the shares
        eTST.redeem(type(uint256).max, depositor, depositor); // depositor should be able to redeem
    }

    function testFuzz_disablingTransferOpsShouldFailAfterDisabled(address to, uint256 amount) public {
        eTST.setDisabledOps(OP_TRANSFER);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.transfer(to, amount);

        // re-enable
        eTST.setDisabledOps(0);
        uint256 balance = eTST.balanceOf(depositor);
        vm.prank(depositor);
        eTST.transfer(to, balance);
    }

    function testFuzz_skimmingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_SKIM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.skim(amount, receiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(depositor);
        // type(uint256).max skims all of the shares
        eTST.skim(type(uint256).max, receiver);
    }

    function testFuzz_borrowingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_BORROW);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.borrow(amount, receiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.startPrank(depositor);
        evc.enableController(depositor, address(eTST));
        vm.assume(receiver != address(0));
        eTST.borrow(type(uint256).max, receiver);
        vm.stopPrank();
    }

    function testFuzz_repayingDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_REPAY);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.repay(amount, receiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(borrower);
        eTST.repay(type(uint256).max, receiver);
    }

    function testFuzz_loopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address sharesReceiver) public {
        eTST.setDisabledOps(OP_LOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.loop(amount, sharesReceiver);

        // re-enable
        eTST.setDisabledOps(0);
        vm.startPrank(depositor);
        evc.enableController(depositor, address(eTST));
        vm.assume(sharesReceiver != address(0));
        eTST.loop(MINT_AMOUNT, sharesReceiver);
        vm.stopPrank();
    }

    function testFuzz_deloopingDisabledOpsShouldFailAfterDisabled(uint256 amount, address debtFrom) public {
        eTST.setDisabledOps(OP_DELOOP);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deloop(amount, debtFrom);

        // re-enable
        eTST.setDisabledOps(0);
        vm.prank(borrower);
        eTST.deloop(amount, borrower);
    }

    function testFuzz_pullingDebtDisabledOpsShouldFailAfterDisabled(uint256 amount, address from) public {
        eTST.setDisabledOps(OP_PULL_DEBT);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.pullDebt(amount, from);

        // re-enable
        eTST.setDisabledOps(0);
        vm.startPrank(depositor);
        evc.enableController(depositor, address(eTST));
        eTST.pullDebt(type(uint256).max, borrower);
    }

    function testFuzz_convertingFeesDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_CONVERT_FEES);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.convertFees();

        // re-enable
        eTST.setDisabledOps(0);
        eTST.convertFees();
    }

    function testFuzz_liquidatingDisabledOpsShouldFailAfterDisabled(
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) public {
        eTST.setDisabledOps(OP_LIQUIDATE);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.liquidate(violator, collateral, repayAssets, minYieldBalance);

        // re-enable
        eTST.setDisabledOps(0);
        liquidateSetup();
    }

    function testFuzz_flashLoanDisabledOpsShouldFailAfterDisabled(uint256 amount, bytes calldata data) public {
        eTST.setDisabledOps(OP_FLASHLOAN);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.flashLoan(amount, data);

        amount = bound(amount, 1, MINT_AMOUNT);
        // re-enable
        eTST.setDisabledOps(0);
        eTST.flashLoan(amount, abi.encode(amount, address(assetTST)));
    }

    function testFuzz_touchDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_TOUCH);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.touch();
    }

    function testFuzz_accrueInterestDisabledOpsShouldFailAfterDisabled() public {
        eTST.setDisabledOps(OP_ACCRUE_INTEREST);

        vm.startPrank(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));
        eTST.borrow(MINT_AMOUNT, borrower);
        uint256 interestAccumulatorBefore = eTST.interestAccumulator();
        skip(1 weeks);
        uint256 interestAccumulatorAfter = eTST.interestAccumulator();
        vm.stopPrank();
        assertEq(interestAccumulatorBefore, interestAccumulatorAfter);

        // re-enable
        eTST.setDisabledOps(0);
        uint256 interestAccumulatorBeforeReEanbled = eTST.interestAccumulator();
        skip(1 weeks);
        uint256 interestAccumulatorAfterReEnabled = eTST.interestAccumulator();
        assertGt(interestAccumulatorAfterReEnabled, interestAccumulatorBeforeReEanbled);
    }

    // TODO: socialize debt is a little bit different
    function testFuzz_socializeDebtDisabledOpsShouldFailAfterDisabled(uint256 amount, address receiver) public {
        eTST.setDisabledOps(OP_SOCIALIZE_DEBT);
        vm.recordLogs();
        liquidateSetup();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            console2.logBytes32(entries[i].topics[0]);
            bytes32 topic = entries[i].topics[0];
            assertNotEq(topic, Events.DebtSocialized.selector);
        }

        // re-enable
        eTST.setDisabledOps(0);
        vm.recordLogs();
        assetTST2.mint(address(this), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(MINT_AMOUNT, address(this));
        liquidateSetup();
        Vm.Log[] memory entriesReEnabled = vm.getRecordedLogs();
        bool foundLog = false;
        for (uint256 i = 0; i < entriesReEnabled.length; i++) {
            console2.logBytes32(entriesReEnabled[i].topics[0]);
            bytes32 topic = entriesReEnabled[i].topics[0];
            if (topic == Events.DebtSocialized.selector) {
                foundLog = true;
                break;
            }
        }
        assertTrue(foundLog);
    }

    function testFuzz_validateAssetsReceiverDisabledShouldFailBorrowAfterDisabled(uint256 amount, address receiver)
        public
    {
        amount = bound(amount, 1, MINT_AMOUNT / 2);
        vm.assume(receiver != address(0));

        address subacc = address(uint160(borrower) >> 8 << 8);

        vm.startPrank(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));
        vm.expectRevert(Errors.E_BadAssetReceiver.selector); //! note this is a different error
        eTST.borrow(amount, subacc);
        vm.stopPrank();

        eTST.setDisabledOps(OP_VALIDATE_ASSET_RECEIVER);

        vm.startPrank(borrower);
        eTST.borrow(amount, subacc);
        vm.stopPrank();

        eTST.setDisabledOps(0);
        vm.startPrank(borrower);
        // should be disabled again
        vm.expectRevert(Errors.E_BadAssetReceiver.selector); //! note this is a different error
        eTST.borrow(amount, subacc);
    }

    // helpers
    function onFlashLoan(bytes calldata data) external {
        // decode data as amount and address
        (uint256 amount, address eTSTAddr) = abi.decode(data, (uint256, address));
        // return the amount to the
        IERC20(eTSTAddr).transfer(address(eTST), amount);
    }

    function liquidateSetup() internal {
        eTST.setLTV(address(eTST2), 1e4, 0);
        oracle.setPrice(address(assetTST), unitOfAccount, 1e4);
        oracle.setPrice(address(eTST2), unitOfAccount, 1.1e4);

        vm.startPrank(borrower);
        evc.enableController(borrower, address(eTST));
        evc.enableCollateral(borrower, address(eTST2));
        eTST.borrow(type(uint256).max, borrower);
        vm.stopPrank();
        skip(1 weeks);
        oracle.setPrice(address(assetTST), unitOfAccount, 10e4);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.5e4);

        // check liquidation
        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(address(this), borrower, address(eTST2));
        console2.log("maxRepay", maxRepay);
        console2.log("maxYield", maxYield);

        evc.enableController(address(this), address(eTST));
        eTST.liquidate(borrower, address(eTST2), maxRepay / 2, 0);
    }
}

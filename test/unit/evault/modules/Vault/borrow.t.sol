// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IRMMax} from "../../../../mocks/IRMMax.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

contract VaultTest_Borrow is EVaultTestBase {
    using TypesLib for uint256;

    address depositor;
    address borrower;
    address borrower2;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");
        borrower2 = makeAddr("borrower_2");

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);

        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        // Borrower

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        vm.stopPrank();
    }

    function test_basicBorrow() public {
        startHoax(borrower);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.borrow(5e18, borrower);

        evc.enableController(borrower, address(eTST));

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST.borrow(5e18, borrower);

        // still no borrow hence possible to disable controller
        assertEq(evc.isControllerEnabled(borrower, address(eTST)), true);
        eTST.disableController();
        assertEq(evc.isControllerEnabled(borrower, address(eTST)), false);
        evc.enableController(borrower, address(eTST));
        assertEq(evc.isControllerEnabled(borrower, address(eTST)), true);

        evc.enableCollateral(borrower, address(eTST2));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);
        assertEq(eTST.debtOf(borrower), 5e18);
        assertEq(eTST.debtOfExact(borrower), 5e18 << INTERNAL_DEBT_PRECISION_SHIFT);

        assertEq(eTST.totalBorrows(), 5e18);
        assertEq(eTST.totalBorrowsExact(), 5e18 << INTERNAL_DEBT_PRECISION_SHIFT);

        // no longer possible to disable controller
        vm.expectRevert(Errors.E_OutstandingDebt.selector);
        eTST.disableController();

        // Should be able to borrow up to 9, so this should fail:

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST.borrow(4.0001e18, borrower);

        // Disable collateral should fail

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        evc.disableCollateral(borrower, address(eTST2));

        // Repay

        assetTST.approve(address(eTST), type(uint256).max);
        eTST.repay(type(uint256).max, borrower);

        evc.disableCollateral(borrower, address(eTST2));
        assertEq(evc.getCollaterals(borrower).length, 0);

        eTST.disableController();
        assertEq(evc.getControllers(borrower).length, 0);
    }

    function test_basicBorrowWithInterest() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);

        skip(1 days);

        uint256 currDebt = eTST.debtOf(borrower);
        assertApproxEqAbs(currDebt, 5.0001e18, 0.0001e18);

        assertEq(eTST.debtOfExact(borrower) >> INTERNAL_DEBT_PRECISION_SHIFT, currDebt - 1); // currDebt was rounded up
        assertEq(eTST.debtOfExact(borrower), eTST.totalBorrowsExact());

        // Repay too much

        assetTST.mint(borrower, 100e18);
        assetTST.approve(address(eTST), type(uint256).max);

        vm.expectRevert(Errors.E_RepayTooMuch.selector);
        eTST.repay(currDebt + 1, borrower);

        // Repay right amount

        eTST.repay(currDebt, borrower);

        assertEq(eTST.debtOf(borrower), 0);
        assertEq(eTST.debtOfExact(borrower), 0);

        assertEq(eTST.totalBorrows(), 0);
        assertEq(eTST.totalBorrowsExact(), 0);
    }

    function test_loopNoop() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        assertEq(eTST.balanceOf(borrower), 0);
        assertEq(eTST.debtOf(borrower), 0);
        eTST.loop(0, borrower);
        assertEq(eTST.balanceOf(borrower), 0);
        assertEq(eTST.debtOf(borrower), 0);
    }

    function test_deloopWithExtra() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        assetTST.mint(borrower, 100e18);
        assetTST.approve(address(eTST), type(uint256).max);

        eTST.loop(2e18, borrower);
        eTST.deposit(1e18, borrower);

        assertEq(eTST.balanceOf(borrower), 3e18);
        assertEq(eTST.debtOf(borrower), 2e18);

        eTST.deloop(type(uint256).max, borrower);

        assertEq(eTST.balanceOf(borrower), 1e18);
        assertEq(eTST.debtOf(borrower), 0);
    }

    function test_repayWithPermit2() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);
        assertEq(assetTST.balanceOf(borrower), 5e18);

        // deposit won't succeed without any approval
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20Lib.E_TransferFromFailed.selector,
                abi.encodeWithSignature("Error(string)", "ERC20: transfer amount exceeds allowance"),
                abi.encodeWithSelector(IAllowanceTransfer.AllowanceExpired.selector, 0)
            )
        );
        eTST.repay(type(uint256).max, borrower);

        // approve permit2 contract to spend the tokens
        assetTST.approve(permit2, type(uint160).max);

        // approve the vault to spend the tokens via permit2
        IAllowanceTransfer(permit2).approve(address(assetTST), address(eTST), type(uint160).max, type(uint48).max);

        // repay succeeds now
        eTST.repay(type(uint256).max, borrower);

        assertEq(eTST.debtOf(borrower), 0);
    }

    function test_pullDebt_when_from_equal_account() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);

        vm.expectRevert(Errors.E_SelfTransfer.selector);
        eTST.pullDebt(amountToBorrow, borrower);
    }

    function test_pullDebt_zero_amount() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        vm.stopPrank();

        startHoax(borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        eTST.pullDebt(0, borrower);
        vm.stopPrank();

        assertEq(eTST.debtOf(borrower), amountToBorrow);
        assertEq(eTST.debtOf(borrower2), 0);
    }

    function test_pullDebt_full_amount() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);

        // transfering some minted asset to borrower2
        assetTST2.transfer(borrower2, 10e18);
        vm.stopPrank();

        startHoax(borrower2);

        // deposit into eTST2 to cover the liability from pullDebt
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        eTST.pullDebt(type(uint256).max, borrower);
        vm.stopPrank();

        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        assertEq(assetTST.balanceOf(borrower2), 0);
        assertEq(eTST.debtOf(borrower), 0);
        assertEq(eTST.debtOf(borrower2), amountToBorrow);
    }

    function test_pullDebt_amount_gt_debt() public {
        startHoax(borrower);
        uint256 amountToBorrow = 5e18;

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(amountToBorrow, borrower);
        assertEq(assetTST.balanceOf(borrower), amountToBorrow);
        assertEq(eTST.debtOf(borrower), amountToBorrow);
        vm.stopPrank();

        startHoax(borrower2);

        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        vm.expectRevert(Errors.E_InsufficientBalance.selector);
        eTST.pullDebt(amountToBorrow + 1, borrower);
        vm.stopPrank();
    }

    function test_ControllerRequiredOps(address controller, uint112 amount, address account) public {
        vm.assume(controller.code.length == 0 && uint160(controller) > 256);
        vm.assume(account != address(0) && account != controller && account != address(evc));
        vm.assume(amount > 0);

        vm.etch(controller, address(eTST).code);
        IEVault(controller).initialize(address(this));

        vm.startPrank(account);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        IEVault(controller).borrow(amount, account);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        IEVault(controller).loop(amount, account);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        IEVault(controller).pullDebt(amount, account);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        IEVault(controller).liquidate(account, account, amount, amount);

        evc.enableController(account, controller);
    }

    function test_Borrow_RevertsWhen_ReceiverIsSubaccount() public {
        // Configure vault as non-EVC compatible: protections on
        eTST.setConfigFlags(eTST.configFlags() & ~CFG_EVC_COMPATIBLE_ASSET);

        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        address subaccBase = address(uint160(borrower) >> 8 << 8);

        // addresses within sub-accounts range revert
        for (uint160 i; i < 256; i++) {
            address subacc = address(uint160(subaccBase) | i);
            if (subacc != borrower) vm.expectRevert(Errors.E_BadAssetReceiver.selector);
            eTST.borrow(1, subacc);
        }
        assertEq(assetTST.balanceOf(borrower), 1);

        // address outside of sub-accounts range are accepted
        address otherAccount = address(uint160(subaccBase) - 1);
        eTST.borrow(1, otherAccount);
        assertEq(assetTST.balanceOf(otherAccount), 1);

        otherAccount = address(uint160(subaccBase) + 256);
        eTST.borrow(1, otherAccount);
        assertEq(assetTST.balanceOf(otherAccount), 1);

        vm.stopPrank();

        // governance switches the protection off
        eTST.setConfigFlags(eTST.configFlags() | CFG_EVC_COMPATIBLE_ASSET);

        startHoax(borrower);

        // borrow is allowed again
        {
            address subacc = address(uint160(borrower) ^ 42);
            assertEq(assetTST.balanceOf(subacc), 0);
            eTST.borrow(1, subacc);
            assertEq(assetTST.balanceOf(subacc), 1);
        }
    }

    function test_rpowOverflow() public {
        eTST.setInterestRateModel(address(new IRMMax()));

        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(1, borrower);

        uint256 accum1 = eTST.interestAccumulator();

        // Skip forward to observe accumulator advancing
        skip(365 * 2 days);
        eTST.touch();
        uint256 accum2 = eTST.interestAccumulator();
        assertTrue(accum2 > accum1);

        // Observe accumulator increasing, without writing it to storage:
        skip(365 * 3 days);
        uint256 accum3 = eTST.interestAccumulator();
        assertTrue(accum3 > accum2);

        // Skip forward more, so that rpow() will overflow
        skip(365 * 3 days);
        uint256 accum4 = eTST.interestAccumulator();
        assertTrue(accum4 == accum2); // Accumulator goes backwards

        // Withdrawing assets is still possible in this state
        startHoax(depositor);
        uint256 prevBal = assetTST.balanceOf(depositor);
        eTST.withdraw(90e18, depositor, depositor);
        assertEq(assetTST.balanceOf(depositor), prevBal + 90e18);
    }

    function test_accumOverflow() public {
        eTST.setInterestRateModel(address(new IRMMax()));

        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(1, borrower);

        uint256 accum1 = eTST.interestAccumulator();

        // Wait 5 years, touching pool each time so that rpow() will not overflow
        for (uint256 i; i < 5; i++) {
            skip(365 * 1 days);
            eTST.touch();
        }

        uint256 accum2 = eTST.interestAccumulator();
        assertTrue(accum2 > accum1);

        // After the 6th year, the accumulator would overflow so it stops growing
        skip(365 * 1 days);
        eTST.touch();
        assertTrue(eTST.interestAccumulator() == accum2);

        // Withdrawing assets is still possible in this state
        startHoax(depositor);
        uint256 prevBal = assetTST.balanceOf(depositor);
        eTST.withdraw(90e18, depositor, depositor);
        assertEq(assetTST.balanceOf(depositor), prevBal + 90e18);
    }

    uint256 tempInterestRate;

    function myCallback() external {
        startHoax(borrower);
        eTST.borrow(1e18, borrower);

        // This interest rate is invoked by immediately calling computeInterestRateView() on the IRM,
        // as opposed to using the stored value.
        tempInterestRate = eTST.interestRate();
    }

    function test_interestRateViewMidBatch() public {
        startHoax(borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        uint256 origInterestRate = eTST.interestRate();
        evc.call(address(this), borrower, 0, abi.encodeWithSelector(VaultTest_Borrow.myCallback.selector));

        assertTrue(tempInterestRate > origInterestRate);
        assertEq(tempInterestRate, eTST.interestRate()); // Value computed at end of batch is identical
    }
}

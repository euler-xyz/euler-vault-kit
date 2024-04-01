// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {GovernanceModule} from "src/EVault/modules/Governance.sol";

import "src/EVault/shared/types/Types.sol";

uint16 constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;
uint16 constant GUARANTEED_INTEREST_FEE_MIN = 0.01e4;
uint16 constant GUARANTEED_INTEREST_FEE_MAX = 0.5e4;

contract GovernanceTest_InterestFee is EVaultTestBase {
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
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);

        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        // Borrower 1

        startHoax(borrower);

        assetTST.mint(borrower, 10e18);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(100e18, borrower);

        // Borrower 2

        startHoax(borrower2);

        assetTST.mint(borrower2, 10e18);

        assetTST2.mint(borrower2, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(100e18, borrower2);
    }

    function test_feesAccrual() public {
        startHoax(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);

        startHoax(borrower2);
        evc.enableCollateral(borrower2, address(eTST2));
        evc.enableController(borrower2, address(eTST));

        eTST.borrow(6e18, borrower2);

        skip(1000);

        uint256 accumFees = eTST.interestFee() * (eTST.debtOf(borrower) + eTST.debtOf(borrower2) - 11e18) / (1e4);

        assertApproxEqAbs(accumFees, eTST.accumulatedFeesAssets(), 10);
    }

    function test_convertFees_AnyInvoke() public {
        startHoax(address(this));
        eTST.convertFees();

        startHoax(admin);
        eTST.convertFees();

        startHoax(feeReceiver);
        eTST.convertFees();

        startHoax(depositor);
        eTST.convertFees();

        startHoax(borrower);
        eTST.convertFees();
    }

    function test_convertFees_NoGovernorReceiver() public {
        startHoax(address(this));
        eTST.setFeeReceiver(address(0));
        assertEq(eTST.feeReceiver(), address(0));

        uint256 accumFee = eTST.accumulatedFees();
        address protocolFeeReceiver = protocolConfig.feeReceiver();

        assertEq(eTST.balanceOf(protocolFeeReceiver), 0);
        eTST.convertFees();
        assertEq(eTST.balanceOf(protocolFeeReceiver), accumFee);
    }

    function test_convertFees_WithGovernorReceiver() public {
        address governFeeReceiver = eTST.feeReceiver();
        address protocolFeeReceiver = protocolConfig.feeReceiver();

        uint256 accumFee = getAccumulatedFees();
        uint256 protocolShare = eTST.protocolFeeShare();
        uint256 partFee = accumFee.toShares().mulDiv(1e4 - protocolShare, 1e4).toUint();
        assertEq(eTST.balanceOf(governFeeReceiver), 0);
        assertEq(eTST.balanceOf(protocolFeeReceiver), 0);
        eTST.convertFees();

        assertEq(eTST.balanceOf(governFeeReceiver), partFee);
        assertEq(eTST.balanceOf(protocolFeeReceiver), accumFee - partFee);
    }

    function test_convertFees_OverMaxProtocolFeeShare() public {
        uint16 newProtocolFeeShare = MAX_PROTOCOL_FEE_SHARE + 0.1e4;

        address governFeeReceiver = eTST.feeReceiver();
        address protocolFeeReceiver = protocolConfig.feeReceiver();

        startHoax(admin);
        protocolConfig.setProtocolFeeShare(newProtocolFeeShare);

        uint256 accumFee = getAccumulatedFees();

        assertEq(eTST.balanceOf(governFeeReceiver), 0);
        assertEq(eTST.balanceOf(protocolFeeReceiver), 0);
        eTST.convertFees();

        uint256 partFee = accumFee.toShares().mulDiv(1e4 - newProtocolFeeShare, 1e4).toUint();
        assertNotEq(eTST.balanceOf(governFeeReceiver), partFee);
        assertNotEq(eTST.balanceOf(protocolFeeReceiver), accumFee - partFee);

        partFee = accumFee.toShares().mulDiv(1e4 - MAX_PROTOCOL_FEE_SHARE, 1e4).toUint();
        assertEq(eTST.balanceOf(governFeeReceiver), partFee);
        assertEq(eTST.balanceOf(protocolFeeReceiver), accumFee - partFee);
    }

    function test_setInterestFee_InsideGuaranteedRange() public {
        uint16 newInterestFee = 0.3e4;

        startHoax(address(this));

        vm.expectEmit();
        emit GovernanceModule.GovSetInterestFee(newInterestFee);

        eTST.setInterestFee(newInterestFee);

        assertEq(eTST.interestFee(), newInterestFee);
    }

    function test_setInterestFee_OutsideGuaranteedRange() public {
        uint16 newInterestFee = 0.05e4;

        startHoax(address(this));
        vm.expectRevert(Errors.E_BadFee.selector);
        eTST.setInterestFee(newInterestFee);
        startHoax(admin);
        protocolConfig.setVaultInterestFeeRange(address(eTST), true, 0, 1e4);

        startHoax(address(this));

        vm.expectEmit();
        emit GovernanceModule.GovSetInterestFee(newInterestFee);

        eTST.setInterestFee(newInterestFee);

        assertEq(eTST.interestFee(), newInterestFee);
    }

    function getAccumulatedFees() internal returns (uint256 accumFee) {
        startHoax(borrower);
        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));

        eTST.borrow(5e18, borrower);

        skip(1000);

        assetTST.approve(address(eTST), type(uint256).max);
        eTST.repay(type(uint256).max, borrower);

        return eTST.accumulatedFees();
    }
}

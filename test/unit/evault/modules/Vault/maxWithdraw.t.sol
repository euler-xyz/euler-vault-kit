// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {TestERC20} from "../../../../mocks/TestERC20.sol";
import {IRMTestZero} from "../../../../mocks/IRMTestZero.sol";

contract VaultTest_MaxWithdraw is EVaultTestBase {
    address lender;
    address borrower;
    address bystander;

    TestERC20 assetTST3;
    IEVault public eTST3;

    TestERC20 assetTST4;
    IEVault public eTST4;

    function setUp() public override {
        super.setUp();

        lender = makeAddr("lender");
        borrower = makeAddr("borrower");
        bystander = makeAddr("bystander");

        assetTST3 = new TestERC20("Test TST 3", "TST3", 18, false);

        eTST3 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST3), address(oracle), unitOfAccount)));

        eTST.setInterestRateModel(address(new IRMTestZero()));
        eTST2.setInterestRateModel(address(new IRMTestZero()));
        eTST3.setInterestRateModel(address(new IRMTestZero()));

        eTST.setLTV(address(eTST2), 0.3e4, 0);

        assetTST.mint(lender, 200e18);
        startHoax(lender);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, lender);

        assetTST3.mint(lender, 200e18);
        startHoax(lender);
        assetTST3.approve(address(eTST3), type(uint256).max);
        eTST3.deposit(100e18, lender);

        assetTST2.mint(borrower, 100e18);
        startHoax(borrower);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(100e18, borrower);
        evc.enableCollateral(borrower, address(eTST2));

        assetTST.mint(bystander, 100e18);
        assetTST2.mint(bystander, 100e18);
        startHoax(bystander);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(30e18, bystander);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(18e18, bystander);

        oracle.setPrice(address(eTST), unitOfAccount, 2.2e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.4e18);
        oracle.setPrice(address(eTST3), unitOfAccount, 2.2e18);
    }

    //can't withdraw deposit not entered as collateral when account unhealthy
    function test_withdraw_accountUnhealthy() public {
        startHoax(borrower);
        evc.enableController(borrower, address(eTST));
        eTST.borrow(5e18, borrower);

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 / liabilityValue, 1.09e18, 0.01e18);

        // depositing but not entering collateral
        assetTST3.mint(borrower, 10e18);
        assetTST3.approve(address(eTST3), type(uint256).max);
        eTST3.deposit(1e18, borrower);

        // account unhealthy
        oracle.setPrice(address(eTST), unitOfAccount, 2.5e18);

        (collateralValue, liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 / liabilityValue, 0.96e18, 0.001e18);

        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        eTST3.withdraw(1e18, borrower, borrower);
    }

    //max withdraw with borrow - deposit not enabled as collateral
    function test_withdraw_depositNotEnabledAsCollateral() public {
        startHoax(borrower);
        evc.enableController(borrower, address(eTST));
        eTST.borrow(5e18, borrower);

        // set up liquidator to support the debt
        startHoax(lender);
        evc.enableController(lender, address(eTST));
        evc.enableCollateral(lender, address(eTST2));
        evc.enableCollateral(lender, address(eTST3));

        startHoax(address(this));
        eTST.setLTV(address(eTST3), 0.95e4, 0);

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 / liabilityValue, 1.09e18, 0.01e18);

        assetTST3.mint(borrower, 100e18);
        startHoax(borrower);
        assetTST3.approve(address(eTST3), type(uint256).max);
        eTST3.deposit(1e18, borrower);

        assertEq(eTST3.maxRedeem(borrower), 1e18);

        oracle.setPrice(address(eTST), unitOfAccount, 2.5e18);
        oracle.setPrice(address(eTST3), unitOfAccount, 2.5e18);

        (collateralValue, liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 / liabilityValue, 0.96e18, 0.001e18);

        // TST3 is not enabled as collateral, so withdrawal is NOT prevented in unhealthy state
        assertEq(eTST3.maxRedeem(borrower), 1e18);
    }
}

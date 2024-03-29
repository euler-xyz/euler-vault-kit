// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";

import {Events} from "src/EVault/shared/Events.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {EVault} from "src/EVault/EVault.sol";
import {IEVault, IERC20} from "src/EVault/IEVault.sol";
import {IRMTestDefault} from "../../../../mocks/IRMTestDefault.sol";
import {TestERC20} from "../../../../mocks/TestERC20.sol";

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

contract VaultLiquidation_Test is EVaultTestBase {

    address lender;
    address borrower;
    address bystander;

    TestERC20 assetWETH;
    TestERC20 assetTST3;

    IEVault public eWETH;
    IEVault public eTST3;

    function setUp() public override {
        super.setUp();

        lender = makeAddr("lender");
        borrower = makeAddr("borrower");
        bystander = makeAddr("bystander");

        address evaultImpl = address(new EVault(integrations, modules));
        
        assetWETH = new TestERC20("Test WETH", "WETH", 18, false);
        assetTST3 = new TestERC20("Test TST 3", "TST3", 18, false);


        eWETH = IEVault(factory.createProxy(true, abi.encodePacked(address(assetWETH), address(oracle), unitOfAccount)));
        eWETH.setInterestRateModel(address(new IRMTestDefault()));

        eTST3 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST3), address(oracle), unitOfAccount)));
        eTST3.setInterestRateModel(address(new IRMTestDefault()));

        eTST.setLTV(address(eWETH), 0.3e4, 0);
        eTST.setLTV(address(eTST2), 0.3e4, 0);

        oracle.setPrice(address(assetTST), unitOfAccount, 2.2e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.4e18);
        oracle.setPrice(address(eTST3), unitOfAccount, 2.2e18);


        startHoax(lender);

        assetWETH.mint(lender, 200e18);
        assetWETH.approve(address(eWETH), type(uint256).max);
        eWETH.deposit(100e18, lender);

        assetTST.mint(lender, 200e18);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, lender);

        assetTST2.mint(lender, 200e18);
        assetTST2.approve(address(eTST2), type(uint256).max);


        assetTST3.mint(lender, 200e18);
        assetTST3.approve(address(eTST3), type(uint256).max);
        eTST3.deposit(100e18, lender);


        startHoax(borrower);

        assetTST2.mint(borrower, 100e18);
        assetTST2.approve(address(eTST2), type(uint256).max);

        assetTST3.mint(borrower, 100e18);
        assetTST3.approve(address(eTST3), type(uint256).max);
        
        eTST2.deposit(100e18, borrower);
        evc.enableCollateral(borrower, address(eTST2));

        startHoax(bystander);

        assetTST.mint(bystander, 100e18);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(30e18, bystander);
        assetTST2.mint(bystander, 100e18);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(18e18, bystander);
        evc.enableCollateral(bystander, address(eTST2));
        
    }

    function test_noViolation() public {

        // Liquidator not in controller

        startHoax(lender);

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.liquidate(borrower, address(eTST), 1, 0);

        evc.enableController(lender, address(eTST));

        vm.expectRevert(Errors.E_BadCollateral.selector);
        eTST.liquidate(borrower, address(eTST), 1, 0);

        // User not in collateral:

        startHoax(address(this));

        eTST.setLTV(address(eTST3), 0.3e4, 0);

        startHoax(borrower);

        evc.enableController(borrower, address(eTST));

        startHoax(lender);

        vm.expectRevert(Errors.E_CollateralDisabled.selector);
        eTST.liquidate(borrower, address(eTST3), 1, 0);

        // User healthy:

        startHoax(borrower);
        
        eTST.borrow(5e18, borrower);

        startHoax(lender);
        
        vm.expectRevert(Errors.E_ExcessiveRepayAmount.selector);
        eTST.liquidate(borrower, address(eTST2), 1, 0);

        // no-op

        vm.expectEmit(true, true, true, true);
        emit Events.Liquidate(lender, borrower, address(eTST2), 0, 0);
        
        eTST.liquidate(borrower, address(eTST2), 0, 0);

        assertEq(eTST2.balanceOf(borrower), 100e18);
        assertEq(eTST.debtOf(borrower), 5e18);

        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        assertEq(maxRepay, 0);
        assertEq(maxYield, 0);

    }

    function test_selfLiquidation() public {
        startHoax(lender);
        evc.enableController(lender, address(eTST));

        vm.expectRevert(Errors.E_SelfLiquidation.selector);
        eTST.liquidate(lender, address(eTST2), 1, 0);
    }

    function test_basicFullLiquidation() public {
        startHoax(borrower);

        evc.enableController(borrower, address(eTST));
        eTST.borrow(5e18, borrower);

        // set up liquidator to support the debt

        startHoax(lender);
        
        evc.enableController(lender, address(eTST));
        evc.enableCollateral(lender, address(eTST3));
        evc.enableCollateral(lender, address(eTST2));

        startHoax(address(this));
        eTST.setLTV(address(eTST3), 0.95e4, 0);

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 /liabilityValue, 1.09e18, 0.01e18);

        oracle.setPrice(address(assetTST), unitOfAccount, 2.5e18);

        (collateralValue, liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertApproxEqAbs(collateralValue * 1e18 /liabilityValue, 0.96e18, 0.001e18);

        uint256 healthScore = collateralValue * 1e18 / liabilityValue;

        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));

        uint256 maxRepayStash = maxRepay;
        uint256 maxYieldStash = maxYield;

        // If repay amount is 0, it's a no-op
        startHoax(lender);
        eTST.liquidate(borrower, address(eTST2), 0, 0);

        // Nothing changed:

        (maxRepay, maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        assertEq(maxRepay, maxRepayStash);
        assertEq(maxYield, maxYieldStash);

        uint256 yieldAssets = eTST2.convertToAssets(maxYield);
        uint256 valYield = oracle.getQuote(yieldAssets, address(eTST2), unitOfAccount);
        uint256 valRepay = oracle.getQuote(maxRepay, address(assetTST), unitOfAccount);

        assertApproxEqAbs(valRepay, valYield * healthScore / 1e18, 0.000000001e18);

        // Try to repay too much
        vm.expectRevert(Errors.E_ExcessiveRepayAmount.selector);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash + 1, 0);

        // minYield too low
        vm.expectRevert(Errors.E_MinYield.selector);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash, maxYieldStash + 1);
        
        // Successful liquidation
        uint256 feeAssets = eTST.accumulatedFeesAssets();
        assertEq(feeAssets, 0);

        // repay full debt
        uint256 debtOf = eTST.debtOf(borrower);
        assertEq(debtOf, maxRepayStash);
        
        uint256 snapshot1 = vm.snapshot();

        eTST.liquidate(borrower, address(eTST2), maxRepayStash, 0);

        vm.revertTo(snapshot1);
        
        // max uint is equivalent to maxRepay
        eTST.liquidate(borrower, address(eTST2), type(uint256).max, 0);

        // liquidator:
        debtOf = eTST.debtOf(lender);
        assertEq(debtOf, maxRepayStash);

        uint256 balance = eTST2.balanceOf(lender);
        assertEq(balance, maxYieldStash);

        // violator:
        startHoax(borrower);

        assertEq(eTST.debtOf(borrower), 0);

        eTST.disableController();
        assertEq(evc.getControllers(borrower).length, 0);
        assertApproxEqAbs(eTST2.balanceOf(borrower), 100e18 - maxYieldStash, 0.0000000000011e18);

        // Confirming innocent bystander's balance not changed:
        assertApproxEqAbs(eTST.balanceOf(bystander), 30e18, 0.01e18);
        assertApproxEqAbs(eTST2.balanceOf(bystander), 18e18, 0.01e18);

    }

    function test_partialLiquidation() public {
        startHoax(borrower);
        evc.enableController(borrower, address(eTST));
        eTST.borrow(5e18, borrower);

        startHoax(lender);
        evc.enableController(lender, address(eTST));
        evc.enableCollateral(lender, address(eTST3));
        evc.enableCollateral(lender, address(eTST2));

        startHoax(address(this));
        eTST.setLTV(address(eTST3), 0.95e4, 0);

        oracle.setPrice(address(assetTST), unitOfAccount, 2.5e18);
        
        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));

        uint256 maxRepayStash = maxRepay / 4;
        uint256 maxYieldStash = maxRepayStash * maxYield / maxRepay;

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);

        uint256 healthScore = collateralValue * 1e18 / liabilityValue;

        startHoax(lender);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash, 0);

        // liquidator:
        uint256 debtOf = eTST.debtOf(lender);
        assertEq(debtOf, maxRepayStash);
        
        // Yield is proportional to how much was repaid
        uint256 balance = eTST2.balanceOf(lender);
        assertEq(balance, maxYieldStash);

        // reserves:
        uint256 reserves = eTST.accumulatedFeesAssets();

        // violator:
        assertEq(eTST.debtOf(borrower), 5e18 - maxRepayStash + reserves);
        assertEq(eTST2.balanceOf(borrower), 100e18 - maxYieldStash);

        // Confirming innocent bystander's balance not changed:
        assertEq(eTST.balanceOf(bystander), 30e18);
        assertEq(eTST2.balanceOf(bystander), 18e18);

    }
    
    function test_reEnterViolator() public {
        startHoax(lender);
        evc.enableController(lender, address(eTST));

        startHoax(borrower);
        evc.enableController(borrower, address(eTST));

        oracle.setPrice(address(assetTST), unitOfAccount, 2.5e18);

        (uint256 maxRepay, ) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        uint256 maxRepayStash = maxRepay;

        // set the liquidator to be operator of the violator in order to be able act on violator's account and defer its liquidity check
        evc.setAccountOperator(borrower, lender, true);
        
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.borrow.selector, 1e18, borrower)
        });

        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: lender,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.liquidate.selector, borrower, address(eTST2), maxRepayStash, 0)
        });

        startHoax(lender);

        vm.expectRevert(Errors.E_ViolatorLiquidityDeferred.selector);

        evc.batch(items);
    }

    function test_minCollateralFactor() public {
        startHoax(borrower);

        evc.enableController(borrower, address(eTST));
        eTST.borrow(5e18, borrower);

        // set up liquidator to support the debt
        startHoax(lender);

        evc.enableController(lender, address(eTST));
        evc.enableCollateral(lender, address(eTST3));
        evc.enableCollateral(lender, address(eTST2));

        startHoax(address(this));
        
        eTST.setLTV(address(eTST3), 0.95e4, 0);
        eTST.setLTV(address(eTST2), 1, 0);

        // Can't exit market
        startHoax(borrower);
        vm.expectRevert(Errors.E_AccountLiquidity.selector);
        evc.disableCollateral(borrower, address(eTST2));

        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        uint256 maxRepayStash = maxRepay;
        uint256 maxYieldStash = maxYield;

        assertEq(eTST.debtOf(borrower), maxRepayStash);

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);

        assertApproxEqAbs(collateralValue * 1e18 / liabilityValue, 0.0003636e18, 0.0000001e18);

        startHoax(lender);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash, 0);

        startHoax(borrower);
        eTST.disableController();

        vm.expectRevert(Errors.E_NoLiability.selector);
        eTST.checkLiquidation(lender, borrower, address(eTST2));
    }

    function test_debtSocialization() public {
        // set up liquidator to support the debt
        startHoax(lender);
        evc.enableController(lender, address(eTST));
        evc.enableCollateral(lender, address(eTST3));
        evc.enableCollateral(lender, address(eTST2));
        
        startHoax(address(this));
        eTST.setLTV(address(eTST3), 0.95e4, 0);
        eTST.setLTV(address(eTST2), 0.99e4, 0);

        startHoax(borrower);
        evc.enableController(borrower, address(eTST));
        eTST.borrow(18e18, borrower);

        startHoax(bystander);
        evc.enableController(bystander, address(eTST));
        eTST.borrow(1e18, bystander);

        assertEq(eTST.totalBorrows(), 19e18);

        uint256 snapshot1 = vm.snapshot();

        oracle.setPrice(address(assetTST), unitOfAccount, 2.7e18);

        (uint256 maxRepay, uint256 maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        uint256 maxRepayStash = maxRepay;
        uint256 maxYieldStash = maxYield;

        assertEq(maxYieldStash, 100e18);

        address[] memory collaterals = evc.getCollaterals(borrower);
        assertEq(collaterals.length, 1);

        startHoax(lender);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash, 0);

        (uint256 collateralValue, uint256 liabilityValue) = eTST.accountLiquidity(borrower, false);
        assertEq(collateralValue, 0);
        assertEq(liabilityValue, 0);

        // 18 borrowed - repay is socialized. 1 + repay remains
        assertEq(eTST.totalBorrows(), 1e18 + maxRepayStash);

        // liquidator:
        assertEq(eTST.debtOf(lender), maxRepayStash);
        assertEq(eTST.balanceOf(lender), maxYieldStash);

        vm.revertTo(snapshot1);

        // no socialization with other collateral balance
        startHoax(borrower);
        evc.enableCollateral(borrower, address(eTST3));
        // just 1 wei
        eTST3.deposit(1, borrower);
        
        oracle.setPrice(address(assetTST), unitOfAccount, 2.7e18);

        (maxRepay, maxYield) = eTST.checkLiquidation(lender, borrower, address(eTST2));
        maxRepayStash = maxRepay;
        maxYieldStash = maxYield;

        assertEq(maxYieldStash, 100e18);

        startHoax(address(this));

        eTST.setConfigFlags(1<<16);


        startHoax(lender);
        eTST.liquidate(borrower, address(eTST2), maxRepayStash, 0);

        // pool takes a loss

        (collateralValue, liabilityValue) = eTST.accountLiquidity(borrower, false);
        uint256 liability = getRiskAdjustedValue(18e18 - maxRepayStash, 2.7e18, 1e18);
        assertEq(liabilityValue, liability);

        // liquidator:
        assertEq(eTST.debtOf(lender), maxRepayStash);
        assertEq(eTST.balanceOf(lender), maxYieldStash);
    }


    function getRiskAdjustedValue(uint256 amount, uint256 price, uint256 factor) public returns(uint256){
        return amount * price / 1e18 * factor / 1e18;
    }

} 

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../EVaultTestBase.t.sol";
import {Errors} from "src/EVault/shared/Errors.sol";
import {Events} from "src/EVault/shared/Events.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {TestERC20} from "../../../../mocks/TestERC20.sol";
import {IRMTestFixed} from "../../../../mocks/IRMTestFixed.sol";
import {IRMTestZero} from "../../../../mocks/IRMTestZero.sol";
import "src/EVault/shared/types/Types.sol";

contract VaultTest_MarketPolicies is EVaultTestBase {
    address user1;
    address user2;

    TestERC20 assetTST3;
    IEVault public eTST3;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        assetTST3 = new TestERC20("Test TST 3", "TST3", 18, false);

        eTST3 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST3), address(oracle), unitOfAccount)));

        startHoax(address(this));
        eTST.setInterestRateModel(address(new IRMTestZero()));
        eTST2.setInterestRateModel(address(new IRMTestZero()));
        eTST3.setInterestRateModel(address(new IRMTestZero()));

        eTST.setLTV(address(eTST2), 0.3e4, 0);
        eTST.setLTV(address(eTST3), 1e4, 0);
        eTST2.setLTV(address(eTST), 0.3e4, 0);
        eTST3.setLTV(address(eTST), 0.3e4, 0);
        eTST3.setLTV(address(eTST2), 0.3e4, 0);

        assetTST.mint(user1, 100e18);
        assetTST3.mint(user1, 200e18);
        startHoax(user1);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        assetTST3.approve(address(eTST3), type(uint256).max);
        evc.enableCollateral(user1, address(eTST));
        evc.enableCollateral(user1, address(eTST3));
        evc.enableCollateral(user1, address(eTST2));
        evc.enableController(user1, address(eTST));
        eTST.deposit(10e18, user1);
        eTST3.deposit(100e18, user1);

        assetTST2.mint(user2, 100e18);
        startHoax(user2);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, user2);
        evc.enableCollateral(user2, address(eTST));
        evc.enableCollateral(user2, address(eTST2));

        oracle.setPrice(address(eTST), unitOfAccount, 0.01e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.083e18);
        oracle.setPrice(address(eTST3), unitOfAccount, 0.083e18);

        skip(31 * 60);
    }

    function test_deposit_simpleSupplyCap() public {
        assertEq(eTST.cash(), 10e18);

        assertEq(eTST.maxDeposit(user1), MAX_SANE_AMOUNT - 10e18);
        assertEq(eTST.maxMint(user1), MAX_SANE_AMOUNT - 10e18);

        // Deposit prevented:
        startHoax(address(this));
        eTST.setCaps(7059, 0);
        assertEq(eTST.maxDeposit(user1), 1e18);
        assertEq(eTST.maxMint(user1), 1e18);
        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.deposit(2e18, user1);

        // Raise Cap and it succeeds:
        startHoax(address(this));
        eTST.setCaps(8339, 0);
        assertEq(eTST.maxDeposit(user1), 3e18);
        startHoax(user1);
        eTST.deposit(2e18, user1);

        // New limit prevents additional deposits:
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.deposit(2e18, user1);

        // Lower supply cap. Withdrawal still works, even though it's not enough withdrawn to solve the policy violation:
        startHoax(address(this));
        eTST.setCaps(32018, 0);
        assertEq(eTST.maxDeposit(user1), 0);
        assertEq(eTST.maxMint(user1), 0);
        startHoax(user1);
        eTST.withdraw(3e18, user1, user1);
        assertEq(eTST.totalSupply(), 9e18);

        // Deposit doesn't work
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.deposit(0.1e18, user1);
    }

    function test_mint_simpleSupplyCap() public {
        assertEq(eTST.totalSupply(), 10e18);

        // Mint prevented:
        startHoax(address(this));
        eTST.setCaps(7059, 0);
        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.mint(2e18, user1);

        // Raise Cap and it succeeds:
        startHoax(address(this));
        eTST.setCaps(8339, 0);
        startHoax(user1);
        eTST.mint(2e18, user1);

        // New limit prevents additional minting:
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.mint(2e18, user1);

        // Lower supply cap. Withdrawal still works, even though it's not enough withdrawn to solve the policy violation:
        startHoax(address(this));
        eTST.setCaps(32018, 0);
        startHoax(user1);
        eTST.withdraw(3e18, user1, user1);

        assertEq(eTST.totalSupply(), 9e18);

        // Mint doesn't work
        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.mint(0.1e18, user1);
    }

    function test_borrow_simpleBorrowCap() public {
        startHoax(user1);
        eTST.borrow(5e18, user1);

        assertEq(eTST.totalBorrows(), 5e18);

        // Borrow prevented:
        startHoax(address(this));
        eTST.setCaps(0, 38418);
        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.borrow(2e18, user1);

        // Raise Cap and it succeeds:
        startHoax(address(this));
        eTST.setCaps(0, 51218);
        startHoax(user1);
        eTST.borrow(2e18, user1);

        // New limit prevents additional borrows:
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.borrow(2e18, user1);

        // Jump time so that new total borrow exceeds the borrow cap due to the interest accrued
        startHoax(address(this));
        eTST.setInterestRateModel(address(new IRMTestFixed()));
        assertApproxEqAbs(eTST.totalBorrows(), 7e18, 0.001e18);

        skip(2 * 365 * 24 * 60 * 60); // 2 years

        assertApproxEqAbs(eTST.totalBorrows(), 8.55e18, 0.001e18);

        // Touch still works, updating total borrows in storage
        skip(1);
        eTST.touch();
        assertApproxEqAbs(eTST.totalBorrows(), 8.55e18, 0.001e18);

        // Repay still works, even though it's not enough repaid to solve the policy violation:
        startHoax(user1);
        eTST.repay(0.15e18, user1);

        assertApproxEqAbs(eTST.totalBorrows(), 8.4e18, 0.001e18);

        // Borrow doesn't work
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.borrow(0.1e18, user1);
    }

    //supply and borrow cap for wind
    function test_loop_supplyBorrowCap() public {
        assertEq(eTST.totalSupply(), 10e18);
        assertEq(eTST.totalBorrows(), 0);

        // Wind prevented:
        startHoax(address(this));
        eTST.setCaps(7699, 32018);
        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.loop(3e18, user1);

        // Wind prevented:
        startHoax(address(this));
        eTST.setCaps(9619, 12818);
        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.loop(3e18, user1);

        // Raise caps and it succeeds:
        startHoax(address(this));
        eTST.setCaps(9619, 32018);
        startHoax(user1);
        eTST.loop(3e18, user1);

        // New limit prevents additional mints:
        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.loop(3e18, user1);

        // Lower supply cap. Unwind still works, even though it's not enough burnt to solve the policy violation:
        startHoax(address(this));
        eTST.setCaps(6418, 6418);
        startHoax(user1);
        eTST.deloop(1e18, user1);
        assertEq(eTST.totalSupply(), 12e18);
        assertEq(eTST.totalBorrows(), 2e18);

        // Deposit doesn't work
        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        eTST.loop(0.1e18, user1);

        // Turn off supply cap. Wind still doesn't work because of borrow cap
        startHoax(address(this));
        eTST.setCaps(6418, 0);
        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        eTST.loop(0.1e18, user1);
    }

    function test_deferralOfSupplyCapCheck() public {
        // Current supply 10, supply cap 15
        assertEq(eTST.totalSupply(), 10e18);

        startHoax(address(this));
        eTST.setCaps(9619, 0);

        // Deferring doesn't allow us to leave the asset in policy violation:
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 10e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        evc.batch(items);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.mint.selector, 10e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        evc.batch(items);

        // Transient violations don't fail the batch:
        items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 10e18, user1)
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 8e18, user1, user1)
        });

        startHoax(user1);
        evc.batch(items);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.mint.selector, 10e18, user1)
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.redeem.selector, 8e18, user1, user1)
        });

        startHoax(user1);
        evc.batch(items);

        assertEq(eTST.totalSupply(), 14e18);
    }

    function test_deferralOfBorrowCapCheck() public {
        // Current borrow 0, borrow cap 5

        assertEq(eTST.totalBorrows(), 0);
        startHoax(address(this));
        eTST.setCaps(0, 32018);

        // Deferring doesn't allow us to leave the asset in policy violation:
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.borrow.selector, 6e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        evc.batch(items);

        // Transient violations don't fail the batch:
        items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.borrow.selector, 6e18, user1)
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.repay.selector, 2e18, user1)
        });

        startHoax(user1);
        evc.batch(items);

        assertEq(eTST.totalBorrows(), 4e18);
    }

    function test_simpleOperationPausing() public {
        // Deposit prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_DEPOSIT);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(5e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.deposit(5e18, user1);

        // Mint prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_MINT);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.mint(5e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.mint(5e18, user1);

        // Withdrawal prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_WITHDRAW);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.withdraw(5e18, user1, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.withdraw(5e18, user1, user1);

        // Redeem prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_REDEEM);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.redeem(5e18, user1, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.redeem(5e18, user1, user1);

        // Loop prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_LOOP);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.loop(5e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.loop(5e18, user1);

        // Deloop prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_DELOOP);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deloop(5e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.deloop(5e18, user1);

        // setup
        startHoax(user1);
        evc.enableController(user1, address(eTST));

        // Borrow prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_BORROW);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.borrow(5e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.borrow(5e18, user1);
        eTST.borrow(5e18, user1);

        // Repay prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_REPAY);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.repay(type(uint256).max, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.repay(type(uint256).max, user1);

        // eVault transfer prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_TRANSFER);
        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.transfer(getSubAccount(user1, 1), 5e18);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.transfer(getSubAccount(user1, 1), 5e18);

        // setup
        startHoax(user2);
        evc.enableController(user2, address(eTST));
        evc.enableCollateral(user2, address(eTST));
        startHoax(user1);
        evc.enableController(user1, address(eTST));
        eTST.deposit(10e18, user1);
        eTST.borrow(5e18, user1);

        // Debt transfer prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_PULL_DEBT);
        startHoax(user2);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.pullDebt(1e18, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user2);
        eTST.pullDebt(1e18, user1);

        //Vault touch prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_TOUCH);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.touch();

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        eTST.touch();

        //Convert fees prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_CONVERT_FEES);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.convertFees();

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        eTST.convertFees();

        //Liquidation prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_LIQUIDATE);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        startHoax(user2);
        eTST.liquidate(user1, address(eTST2), 0, 0);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user2);
        eTST.liquidate(user1, address(eTST2), 0, 0);

        //Skim prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_SKIM);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        startHoax(user1);
        eTST.skim(0, user1);

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(user1);
        eTST.skim(0, user1);

        //Vault status check prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_VAULT_STATUS_CHECK);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        startHoax(address(eTST));
        evc.requireVaultStatusCheck();

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        startHoax(address(eTST));
        evc.requireVaultStatusCheck();

        //FlashLoan prevented:
        startHoax(address(this));
        eTST.setHookConfig(address(0), OP_FLASHLOAN);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.flashLoan(10, abi.encode(address(eTST), address(assetTST), 10));

        // Remove pause and it succeeds:
        startHoax(address(this));
        eTST.setHookConfig(address(0), 0);
        eTST.flashLoan(10, abi.encode(address(eTST), address(assetTST), 10));
    }

    function test_complexScenario() public {
        startHoax(address(this));
        eTST2.setLTV(address(eTST), 1e4, 0);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.01e18);

        assertEq(eTST.totalSupply(), 10e18);
        assertEq(eTST2.totalSupply(), 10e18);
        assertEq(eTST.totalBorrows(), 0);
        assertEq(eTST2.totalBorrows(), 0);

        eTST.setCaps(9619, 0);
        eTST2.setCaps(0, 32018);
        eTST2.setHookConfig(address(0), OP_LOOP);

        // This won't work because the end state violates market policies:

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](6);
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.disableController.selector)
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, user1, address(eTST2))
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 7e18, user1)
        });
        items[3] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.borrow.selector, 7e18, user1)
        });
        items[4] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 1e18, user1, user1)
        });
        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.repay.selector, 3e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_SupplyCapExceeded.selector);
        evc.batch(items);

        items[4] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 3e18, user1, user1)
        });
        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.repay.selector, 1e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_BorrowCapExceeded.selector);
        evc.batch(items);

        // Succeeeds if there's no violation:

        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.repay.selector, 3e18, user1)
        });

        startHoax(user1);
        evc.batch(items);

        eTST.withdraw(4e18, user1, user1);
        eTST2.repay(type(uint256).max, user1);
        // Fails again if wind item added:
        eTST.disableController();

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, user1, address(eTST2))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 7e18, user1)
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.borrow.selector, 7e18, user1)
        });
        items[3] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.loop.selector, 0, user1)
        });
        items[4] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 1e18, user1, user1)
        });
        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.repay.selector, 3e18, user1)
        });

        startHoax(user1);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        evc.batch(items);

        // Succeeds if wind item added for TST instead of TST2:
        items = new IEVC.BatchItem[](9);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, user1, address(eTST))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, user1, address(eTST2))
        });
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 7e18, user1)
        });
        items[3] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.borrow.selector, 7e18, user1)
        });
        items[4] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.loop.selector, 1e18, user1)
        });
        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 4e18, user1, user1)
        });
        items[6] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.repay.selector, type(uint256).max, user1)
        });
        items[7] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.repay.selector, type(uint256).max, user1)
        });
        items[8] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.disableController.selector)
        });

        startHoax(user1);
        evc.batch(items);

        // checkpoint:
        assertEq(eTST.totalSupply(), 14e18);
        assertEq(eTST2.totalSupply(), 10e18);
        assertEq(eTST.totalBorrows(), 0);
        assertEq(eTST2.totalBorrows(), 0);

        // set new market policies:
        startHoax(address(this));
        eTST.setCaps(6419, 6418);
        eTST2.setCaps(6418, 6418);

        items = new IEVC.BatchItem[](8);

        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, user1, address(eTST2))
        });
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: address(0),
            targetContract: address(evc),
            value: 0,
            data: abi.encodeWithSelector(evc.enableController.selector, getSubAccount(user1, 1), address(eTST2))
        });
        // this exceeds the borrow cap temporarily
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.borrow.selector, 7e18, user1)
        });
        // this exceeds the supply cap temporarily
        items[3] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.deposit.selector, type(uint256).max, getSubAccount(user1, 1))
        });
        // this exceeds the borrow cap temporarily
        items[4] = IEVC.BatchItem({
            onBehalfOfAccount: getSubAccount(user1, 1),
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.pullDebt.selector, type(uint256).max, user1)
        });
        // this exceeds the supply cap temporarily
        items[5] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.deposit.selector, 1e18, user1)
        });
        // this should deloop TST2 debt and deposits, leaving the TST2 borrow cap no longer violated
        // TST2 supply cap is not an issue, although exceeded, total balances stayed the same within the transaction
        items[6] = IEVC.BatchItem({
            onBehalfOfAccount: getSubAccount(user1, 1),
            targetContract: address(eTST2),
            value: 0,
            data: abi.encodeWithSelector(eTST2.deloop.selector, type(uint256).max, getSubAccount(user1, 1))
        });
        // this should withdraw more TST than deposited, leaving the TST supply cap no longer violated
        items[7] = IEVC.BatchItem({
            onBehalfOfAccount: user1,
            targetContract: address(eTST),
            value: 0,
            data: abi.encodeWithSelector(eTST.withdraw.selector, 2e18, user1, user1)
        });

        startHoax(user1);
        evc.batch(items);

        assertEq(eTST.totalSupply(), 13e18);
        assertEq(eTST2.totalSupply(), 10e18);
        assertEq(eTST.totalBorrows(), 0);
        assertEq(eTST2.totalBorrows(), 0);
    }

    function getSubAccount(address primary, uint8 subAccountId) internal pure returns (address) {
        require(subAccountId <= 256, "invalid subAccountId");
        return address(uint160(uint160(primary) ^ subAccountId));
    }

    function onFlashLoan(bytes memory data) external {
        (address eTSTAddress, address assetTSTAddress, uint256 repayAmount) =
            abi.decode(data, (address, address, uint256));

        IERC20(assetTSTAddress).transfer(eTSTAddress, repayAmount);
    }
}

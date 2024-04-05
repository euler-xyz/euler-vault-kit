// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {
    EVaultTestBase, EVault, Base, Dispatch, TypesLib, GenericFactory, IRMTestDefault
} from "../EVaultTestBase.t.sol";
import {EVCClient} from "src/EVault/shared/EVCClient.sol";
// import {SafeERC20Lib} from "src/EVault/shared/lib/SafeERC20Lib.sol";

import "src/EVault/shared/types/Types.sol";
import "src/EVault/shared/Constants.sol";

// a contract with a function that does not use the callThroughEVC() modifier
contract VaultWithBug is EVault {
    using TypesLib for uint256;

    constructor(Base.Integrations memory _integrations, Dispatch.DeployedModules memory _modules)
        EVault(_integrations, _modules)
    {}

    function borrow100X(uint256 amount, address receiver) public returns (uint256) {
        (VaultCache memory vaultCache, address account) = initOperation(OP_BORROW, CHECKACCOUNT_CALLER);

        Assets assets = amount == type(uint256).max ? vaultCache.cash : amount.toAssets();
        if (assets.isZero()) return 0;

        if (assets > vaultCache.cash) revert E_InsufficientCash();

        increaseBorrow(vaultCache, account, assets);

        pushAssets(vaultCache, receiver, assets);

        return assets.toUint();
    }
}

contract EVCClientUnitTest is EVaultTestBase {
    using TypesLib for uint256;

    address public depositor;
    address public borrower;

    function setUp() public override {
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

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

        vm.stopPrank();
    }

    function test_functionWithNo_callThroughEVC() public {
        VaultWithBug bVault = VaultWithBug(setUpBuggyVault());

        vm.startPrank(borrower);
        assetTST2.approve(address(bVault), type(uint256).max);
        bVault.deposit(10e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(bVault));

        vm.expectRevert(Errors.E_Unauthorized.selector);
        bVault.borrow100X(5e18, borrower);
        vm.stopPrank();
    }

    function test_non_CONTROLLER_NEUTRAL_OPS_without_enableController() public {
        startHoax(borrower);

        // OP_BORROW
        evc.enableCollateral(borrower, address(eTST2));

        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.borrow(5e18, borrower);

        // OP_LOOP
        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.loop(5e18, borrower);

        // OP_PULL_DEBT
        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.pullDebt(5e18, borrower);

        vm.stopPrank();

        // OP_LIQUIDATE
        address liquidator = makeAddr("liquidator");
        startHoax(liquidator);
        evc.enableCollateral(liquidator, address(eTST2));
        vm.expectRevert(Errors.E_ControllerDisabled.selector);
        eTST.liquidate(borrower, address(eTST2), type(uint256).max, 0);
        vm.stopPrank();
    }

    function setUpBuggyVault() internal returns (address) {
        admin = makeAddr("admin");
        feeReceiver = makeAddr("feeReceiver");
        protocolFeeReceiver = makeAddr("protocolFeeReceiver");

        vm.startPrank(admin);
        address bVaultImpl = address(new VaultWithBug(integrations, modules));
        GenericFactory factory = new GenericFactory(admin);

        factory.setImplementation(address(bVaultImpl));
        IEVault v =
            IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST2), address(oracle), unitOfAccount)));
        v.setInterestRateModel(address(new IRMTestDefault()));

        return address(v);
    }
}

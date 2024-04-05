// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {EVaultTestBase} from "../unit/evault/EVaultTestBase.t.sol";
import {EVault} from "src/EVault/EVault.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {IRMTestDefault} from "../mocks/IRMTestDefault.sol";
import "src/EVault/modules/BalanceForwarder.sol";
import "src/EVault/modules/Borrowing.sol";
import "src/EVault/modules/Governance.sol";
import "src/EVault/modules/Initialize.sol";
import "src/EVault/modules/Liquidation.sol";
import "src/EVault/modules/RiskManager.sol";
import "src/EVault/modules/Token.sol";
import "src/EVault/modules/Vault.sol";

contract EntryPoint is Test {
    IEVault immutable eTST;
    IEVault immutable eTST2;
    address account1;
    address account2;
    address account3;

    error EVault_Panic();

    constructor(IEVault eTST_, IEVault eTST2_) {
        eTST = eTST_;
        eTST2 = eTST2_;

        account1 = makeAddr("account1");
        account2 = makeAddr("account2");
        account3 = makeAddr("account3");
    }

    function boundAmount(uint256 amount) private pure returns (uint256) {
        return bound(amount, 1, type(uint64).max);
    }

    function boundAddress(address addr) private view returns (address) {
        uint256 remainder = uint160(addr) % 3;
        return remainder == 0 ? account1 : remainder == 1 ? account2 : account3;
    }

    function transfer(address to, uint256 amount) public {
        to = boundAddress(to);
        amount = boundAmount(amount);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.transfer(to, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on transfer");
        }
    }

    function transferFrom(address from, address to, uint256 amount) public {
        from = boundAddress(from);
        to = boundAddress(to);
        amount = boundAmount(amount);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.transferFrom(from, to, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on transferFrom");
        }
    }

    function approve(address spender, uint256 amount) public {
        spender = boundAddress(spender);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.approve(spender, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on approve");
        }
    }

    function transferFromMax(address from, address to) public {
        from = boundAddress(from);
        to = boundAddress(to);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.transferFromMax(from, to) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on transferFromMax");
        }
    }

    function deposit(uint256 amount, address receiver) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.deposit(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on deposit");
        }
    }

    function mint(uint256 amount, address receiver) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.mint(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on mint");
        }
    }

    function withdraw(uint256 amount, address receiver, address owner) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);
        owner = boundAddress(owner);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.withdraw(amount, receiver, owner) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on withdraw");
        }
    }

    function redeem(uint256 amount, address receiver, address owner) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);
        owner = boundAddress(owner);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.redeem(amount, receiver, owner) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on redeem");
        }
    }

    function skim(uint256 amount, address receiver) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.skim(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on skim");
        }
    }

    function borrow(uint256 amount, address receiver) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.borrow(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on borrow");
        }
    }

    function repay(uint256 amount, address receiver) public {
        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.repay(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on repay");
        }
    }

    function loop(uint256 amount, address sharesReceiver) public {
        amount = boundAmount(amount);
        sharesReceiver = boundAddress(sharesReceiver);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.loop(amount, sharesReceiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on loop");
        }
    }

    function deloop(uint256 amount, address debtFrom) public {
        amount = boundAmount(amount);
        debtFrom = boundAddress(debtFrom);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.deloop(amount, debtFrom) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on deloop");
        }
        assert(false);
    }

    function pullDebt(uint256 amount, address from) public {
        amount = boundAmount(amount);
        from = boundAddress(from);

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.pullDebt(amount, from) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on pullDebt");
        }
    }

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) public {
        violator = boundAddress(violator);
        collateral = address(eTST2);
        repayAssets = boundAmount(repayAssets);
        minYieldBalance = 0;

        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.liquidate(violator, collateral, repayAssets, minYieldBalance) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on liquidate");
        }
    }

    function convertFees() public {
        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.convertFees() {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on convertFees");
        }
    }

    function touch() public {
        vm.stopPrank();
        vm.prank(msg.sender);

        try eTST.touch() {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) revert("EVK Panic on touch");
        }
    }
}

contract BalanceForwarderOverride is BalanceForwarder {
    error EVault_Panic();

    constructor(Integrations memory integrations) BalanceForwarder(integrations) {}
}

contract BorrowingOverride is Borrowing {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Borrowing(integrations) {}

    function initOperation(uint32 operation, address accountToCheck)
        internal
        override
        returns (VaultCache memory vaultCache, address account)
    {
        (vaultCache, account) = super.initOperation(operation, accountToCheck);

        vaultStorage.hookedOps = Flags.wrap(Flags.unwrap(vaultStorage.hookedOps) | INIT_OPERATION_FLAG);
    }

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal override {
        super.increaseBalance(vaultCache, account, sender, amount, assets);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal override {
        super.decreaseBalance(vaultCache, account, sender, receiver, amount, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account)
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);

        if (
            !evc.isAccountStatusCheckDeferred(from) || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account) || !evc.isControllerEnabled(account, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);

        if (
            !evc.isAccountStatusCheckDeferred(to) || !evc.isControllerEnabled(to, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }
}

contract GovernanceOverride is Governance {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Governance(integrations) {}

    function initOperation(uint32 operation, address accountToCheck)
        internal
        override
        returns (VaultCache memory vaultCache, address account)
    {
        (vaultCache, account) = super.initOperation(operation, accountToCheck);

        vaultStorage.hookedOps = Flags.wrap(Flags.unwrap(vaultStorage.hookedOps) | INIT_OPERATION_FLAG);
    }

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal override {
        super.increaseBalance(vaultCache, account, sender, amount, assets);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal override {
        super.decreaseBalance(vaultCache, account, sender, receiver, amount, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account)
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);

        if (
            !evc.isAccountStatusCheckDeferred(from) || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account) || !evc.isControllerEnabled(account, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);

        if (
            !evc.isAccountStatusCheckDeferred(to) || !evc.isControllerEnabled(to, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }
}

contract InitializeOverride is Initialize {
    error EVault_Panic();

    constructor(Integrations memory integrations) Initialize(integrations) {}
}

contract LiquidationOverride is Liquidation {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Liquidation(integrations) {}

    function initOperation(uint32 operation, address accountToCheck)
        internal
        override
        returns (VaultCache memory vaultCache, address account)
    {
        (vaultCache, account) = super.initOperation(operation, accountToCheck);

        vaultStorage.hookedOps = Flags.wrap(Flags.unwrap(vaultStorage.hookedOps) | INIT_OPERATION_FLAG);
    }

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal override {
        super.increaseBalance(vaultCache, account, sender, amount, assets);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal override {
        super.decreaseBalance(vaultCache, account, sender, receiver, amount, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account)
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);

        if (
            !evc.isAccountStatusCheckDeferred(from) || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account) || !evc.isControllerEnabled(account, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);

        if (
            !evc.isAccountStatusCheckDeferred(to) || !evc.isControllerEnabled(to, address(this))
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }
}

contract RiskManagerOverride is RiskManager {
    error EVault_Panic();

    constructor(Integrations memory integrations) RiskManager(integrations) {}
}

contract TokenOverride is Token {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Token(integrations) {}

    function initOperation(uint32 operation, address accountToCheck)
        internal
        override
        returns (VaultCache memory vaultCache, address account)
    {
        (vaultCache, account) = super.initOperation(operation, accountToCheck);

        vaultStorage.hookedOps = Flags.wrap(Flags.unwrap(vaultStorage.hookedOps) | INIT_OPERATION_FLAG);
    }

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal override {
        super.increaseBalance(vaultCache, account, sender, amount, assets);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal override {
        super.decreaseBalance(vaultCache, account, sender, receiver, amount, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account)
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);

        if (
            !evc.isAccountStatusCheckDeferred(from) || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }
}

contract VaultOverride is Vault {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Vault(integrations) {}

    function initOperation(uint32 operation, address accountToCheck)
        internal
        override
        returns (VaultCache memory vaultCache, address account)
    {
        (vaultCache, account) = super.initOperation(operation, accountToCheck);

        vaultStorage.hookedOps = Flags.wrap(Flags.unwrap(vaultStorage.hookedOps) | INIT_OPERATION_FLAG);
    }

    function increaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        Shares amount,
        Assets assets
    ) internal override {
        super.increaseBalance(vaultCache, account, sender, amount, assets);

        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) revert EVault_Panic();
    }

    function decreaseBalance(
        VaultCache memory vaultCache,
        address account,
        address sender,
        address receiver,
        Shares amount,
        Assets assets
    ) internal override {
        super.decreaseBalance(vaultCache, account, sender, receiver, amount, assets);

        if (
            !evc.isAccountStatusCheckDeferred(account)
                || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);

        if (
            !evc.isAccountStatusCheckDeferred(from) || (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0)
        ) {
            revert EVault_Panic();
        }
    }
}

contract EVault_Invariant is EVaultTestBase {
    address entryPoint;
    address account1;
    address account2;
    address account3;

    function setUp() public override {
        // Setup

        super.setUp();

        eTST2 = IEVault(factory.createProxy(false, abi.encodePacked(assetTST2, oracle, unitOfAccount)));
        eTST2.setInterestRateModel(address(new IRMTestDefault()));

        initializeModule = address(new InitializeOverride(integrations));
        tokenModule = address(new TokenOverride(integrations));
        vaultModule = address(new VaultOverride(integrations));
        borrowingModule = address(new BorrowingOverride(integrations));
        liquidationModule = address(new LiquidationOverride(integrations));
        riskManagerModule = address(new RiskManagerOverride(integrations));
        balanceForwarderModule = address(new BalanceForwarderOverride(integrations));
        governanceModule = address(new GovernanceOverride(integrations));

        modules.initialize = initializeModule;
        modules.token = tokenModule;
        modules.vault = vaultModule;
        modules.borrowing = borrowingModule;
        modules.liquidation = liquidationModule;
        modules.riskManager = riskManagerModule;
        modules.balanceForwarder = balanceForwarderModule;
        modules.governance = governanceModule;

        address newEVaultImpl = address(new EVault(integrations, modules));

        vm.prank(admin);
        factory.setImplementation(newEVaultImpl);

        eTST = IEVault(factory.createProxy(false, abi.encodePacked(assetTST, oracle, unitOfAccount)));
        eTST.setInterestRateModel(address(new IRMTestDefault()));

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);

        // Accounts

        account1 = makeAddr("account1");

        assetTST.mint(account1, type(uint256).max);
        assetTST2.mint(account1, type(uint256).max);

        vm.startPrank(account1);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(1e24, account1);
        evc.enableController(account1, address(eTST));
        evc.enableCollateral(account1, address(eTST2));
        vm.stopPrank();

        account2 = makeAddr("account2");

        assetTST.mint(account2, type(uint256).max);
        assetTST2.mint(account2, type(uint256).max);

        vm.startPrank(account2);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(1e24, account2);
        evc.enableController(account2, address(eTST));
        evc.enableCollateral(account2, address(eTST2));
        vm.stopPrank();

        account3 = makeAddr("account3");

        assetTST.mint(account3, type(uint256).max);
        assetTST2.mint(account3, type(uint256).max);

        vm.startPrank(account3);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(1e24, account3);
        evc.enableController(account3, address(eTST));
        evc.enableCollateral(account3, address(eTST2));
        vm.stopPrank();

        // Fuzzer setup

        targetSender(account1);
        targetSender(account2);
        targetSender(account3);

        entryPoint = address(new EntryPoint(eTST, eTST2));
        targetContract(entryPoint);
    }

    function test_Simple(uint256 amount, address account) external {
        vm.startPrank(account2);

        //EVaultWrapper(eVaultWrapper).pullDebt(18446744073709551615, 0xd4D7b9C047E1B06ccE298c883C1D8B2f642A5d06);

        //EVaultWrapper(eVaultWrapper).deposit(18446744073709551615, 0xd4D7b9C047E1B06ccE298c883C1D8B2f642A5d06);
        //EVaultWrapper(eVaultWrapper).borrow(amount / 10, account);
        //EVaultWrapper(eVaultWrapper).deloop(amount / 100, account);
        assertTrue(true);
    }

    function invariant_Simple() external {
        assertTrue(true);
    }
}

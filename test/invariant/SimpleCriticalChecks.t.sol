// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "../unit/evault/EVaultTestBase.t.sol";
import {EVault} from "src/EVault/EVault.sol";
import {IEVault} from "src/EVault/IEVault.sol";
import {IRMTestDefault} from "../mocks/IRMTestDefault.sol";
import {MockPriceOracle} from "../mocks/MockPriceOracle.sol";
import "src/EVault/modules/BalanceForwarder.sol";
import "src/EVault/modules/Borrowing.sol";
import "src/EVault/modules/Governance.sol";
import "src/EVault/modules/Initialize.sol";
import "src/EVault/modules/Liquidation.sol";
import "src/EVault/modules/RiskManager.sol";
import "src/EVault/modules/Token.sol";
import "src/EVault/modules/Vault.sol";
import "forge-std/Console.sol";

// Entry Point contract for the fuzzer. Bounds the inputs and prepares the environment for the tests.
contract EntryPoint is Test {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    IEVC immutable evc;
    address immutable governor;
    IEVault[] eTST;
    address[] account;
    string[] errors;

    IEVault selectedVault;

    constructor(IEVault[] memory eTST_, address[] memory account_) {
        evc = IEVC(eTST_[0].EVC());
        governor = eTST_[0].governorAdmin();

        eTST = new IEVault[](eTST_.length);
        eTST = eTST_;

        account = new address[](account_.length);
        account = account_;
    }

    function getErrors() public view returns (string[] memory) {
        return errors;
    }

    // this modifier disables prank mode after the call and checks if the accounts are healthy
    modifier afterCall() {
        _;
        vm.stopPrank();

        if (bytes4(msg.data) != EntryPoint(address(this)).liquidate.selector) {
            for (uint256 i = 0; i < account.length; i++) {
                address[] memory controllers = evc.getControllers(account[i]);

                if (controllers.length == 0) break;

                (uint256 collateralValue, uint256 liabilityValue) =
                    IEVault(controllers[0]).accountLiquidity(account[i], false);

                if (liabilityValue != 0 && liabilityValue >= collateralValue) {
                    errors.push("EVault Panic on afterCall");
                }
            }
        }
    }

    // this function prepares the environment:
    // 1. sets the special bit in the hooked ops bitfield so that it's possible whether initOperation was called
    // 2. tries to disable the controller of the selected vault and checks if the debt is zero
    // 3. enables random vault as a controller
    function setupEnvironment(uint256 seed) private {
        delete errors;

        vm.stopPrank();
        vm.startPrank(governor);
        selectedVault = eTST[seed % eTST.length];
        (address hookTarget, uint32 hookedOps) = selectedVault.hookConfig();
        selectedVault.setHookConfig(hookTarget, hookedOps & ~INIT_OPERATION_FLAG);
        vm.stopPrank();

        vm.startPrank(msg.sender);

        try selectedVault.disableController() {
            if (selectedVault.debtOf(msg.sender) != 0) errors.push("EVault Panic on disableController");
        } catch {
            assertTrue(true);
        }

        try evc.enableController(msg.sender, address(eTST[uint256(keccak256(abi.encode(seed))) % eTST.length])) {
            assertTrue(true);
        } catch {
            assertTrue(true);
        }
    }

    function boundAmount(uint256 amount) private pure returns (uint256) {
        return bound(amount, 1, type(uint64).max);
    }

    function boundAddress(address addr) private view returns (address) {
        return account[uint160(addr) % account.length];
    }

    function transfer(uint256 seed, address to, uint256 amount) public afterCall {
        setupEnvironment(seed);

        to = boundAddress(to);
        amount = boundAmount(amount);

        try selectedVault.transfer(to, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on transfer");
        }
    }

    function transferFrom(uint256 seed, address from, address to, uint256 amount) public afterCall {
        setupEnvironment(seed);

        from = boundAddress(from);
        to = boundAddress(to);
        amount = boundAmount(amount);

        try selectedVault.transferFrom(from, to, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on transferFrom");
        }
    }

    function approve(uint256 seed, address spender, uint256 amount) public afterCall {
        setupEnvironment(seed);

        spender = boundAddress(spender);

        try selectedVault.approve(spender, amount) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on approve");
        }
    }

    function transferFromMax(uint256 seed, address from, address to) public afterCall {
        setupEnvironment(seed);

        from = boundAddress(from);
        to = boundAddress(to);

        try selectedVault.transferFromMax(from, to) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on transferFromMax");
        }
    }

    function deposit(uint256 seed, uint256 amount, address receiver) public afterCall {
        setupEnvironment(seed);

        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        try selectedVault.deposit(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on deposit");
        }
    }

    function mint(uint256 seed, uint256 amount, address receiver) public afterCall {
        setupEnvironment(seed);

        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        try selectedVault.mint(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on mint");
        }
    }

    function withdraw(uint256 seed, uint256 amount, address receiver, address owner) public afterCall {
        setupEnvironment(seed);

        amount = boundAmount(amount);
        receiver = boundAddress(receiver);
        owner = boundAddress(owner);

        try selectedVault.withdraw(amount, receiver, owner) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on withdraw");
        }
    }

    function redeem(uint256 seed, uint256 amount, address receiver, address owner) public afterCall {
        setupEnvironment(seed);

        receiver = boundAddress(receiver);
        owner = boundAddress(owner);

        try selectedVault.redeem(amount, receiver, owner) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on redeem");
        }
    }

    function skim(uint256 seed, uint256 amount, address receiver) public afterCall {
        setupEnvironment(seed);

        receiver = boundAddress(receiver);

        try selectedVault.skim(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on skim");
        }
    }

    function borrow(uint256 seed, uint256 amount, address receiver) public afterCall {
        setupEnvironment(seed);

        amount = boundAmount(amount);
        receiver = boundAddress(receiver);

        try selectedVault.borrow(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on borrow");
        }
    }

    function repay(uint256 seed, uint256 amount, address receiver) public afterCall {
        setupEnvironment(seed);

        receiver = boundAddress(receiver);

        try selectedVault.repay(amount, receiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on repay");
        }
    }

    function loop(uint256 seed, uint256 amount, address sharesReceiver) public afterCall {
        setupEnvironment(seed);

        amount = boundAmount(amount);
        sharesReceiver = boundAddress(sharesReceiver);

        try selectedVault.loop(amount, sharesReceiver) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on loop");
        }
    }

    function deloop(uint256 seed, uint256 amount, address debtFrom) public afterCall {
        setupEnvironment(seed);

        debtFrom = boundAddress(debtFrom);

        try selectedVault.deloop(amount, debtFrom) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on deloop");
        }
    }

    function pullDebt(uint256 seed, uint256 amount, address from) public afterCall {
        setupEnvironment(seed);

        from = boundAddress(from);

        try selectedVault.pullDebt(amount, from) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on pullDebt");
        }
    }

    function liquidate(uint256 seed, address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance)
        public
        afterCall
    {
        setupEnvironment(seed);

        violator = boundAddress(violator);
        collateral = selectedVault.LTVList()[0];
        repayAssets = boundAmount(repayAssets);
        minYieldBalance = 0;

        address oracle = selectedVault.oracle();

        // set lower price for collateral so that maybe a liquidation opportunity occurs
        MockPriceOracle(oracle).setPrice(collateral, selectedVault.unitOfAccount(), 1e17);

        try selectedVault.liquidate(violator, collateral, repayAssets, minYieldBalance) {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on liquidate");
        }

        // set the price back to normal
        MockPriceOracle(oracle).setPrice(collateral, selectedVault.unitOfAccount(), 1e18);
    }

    function convertFees() public afterCall {
        setupEnvironment(0);

        try selectedVault.convertFees() {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on convertFees");
        }
    }

    function touch() public afterCall {
        setupEnvironment(0);

        try selectedVault.touch() {
            assertTrue(true);
        } catch (bytes memory reason) {
            if (bytes4(reason) == EVault_Panic.selector) errors.push("EVault Panic on touch");
        }
    }

    function testExcludeFromCoverage() public pure {}
}

// Modules overrides to check invariants.
// EVault must also be overriden to check invariants for embedded functions called with super.
contract BalanceForwarderOverride is BalanceForwarder {
    error EVault_Panic();

    constructor(Integrations memory integrations) BalanceForwarder(integrations) {}

    function testExcludeFromCoverage() public pure {}
}

contract BorrowingOverride is Borrowing {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Borrowing(integrations) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);
        checkInvariants(account, account);
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);
        checkInvariants(address(0), account);
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);
        checkInvariants(address(0), from);
        checkInvariants(to, to);
    }

    function testExcludeFromCoverage() public pure {}
}

contract GovernanceOverride is Governance {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Governance(integrations) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);
        checkInvariants(account, account);
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);
        checkInvariants(address(0), account);
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);
        checkInvariants(address(0), from);
        checkInvariants(to, to);
    }

    function testExcludeFromCoverage() public pure {}
}

contract InitializeOverride is Initialize {
    error EVault_Panic();

    constructor(Integrations memory integrations) Initialize(integrations) {}

    function testExcludeFromCoverage() public pure {}
}

contract LiquidationOverride is Liquidation {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Liquidation(integrations) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal override {
        super.increaseBorrow(vaultCache, account, assets);
        checkInvariants(account, account);
    }

    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets amount) internal override {
        super.decreaseBorrow(vaultCache, account, amount);
        checkInvariants(address(0), account);
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal override {
        super.transferBorrow(vaultCache, from, to, assets);
        checkInvariants(address(0), from);
        checkInvariants(to, to);
    }

    function testExcludeFromCoverage() public pure {}
}

contract RiskManagerOverride is RiskManager {
    error EVault_Panic();

    constructor(Integrations memory integrations) RiskManager(integrations) {}

    function testExcludeFromCoverage() public pure {}
}

contract TokenOverride is Token {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Token(integrations) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function testExcludeFromCoverage() public pure {}
}

contract VaultOverride is Vault {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations) Vault(integrations) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function testExcludeFromCoverage() public pure {}
}

contract EVaultOverride is EVault {
    uint32 internal constant INIT_OPERATION_FLAG = 1 << 31;

    error EVault_Panic();

    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    function checkInvariants(address checkedAccount, address controllerEnabled) internal view {
        if (Flags.unwrap(vaultStorage.hookedOps) & INIT_OPERATION_FLAG == 0) {
            console.log("EVault Panic on InitOperation");
            revert EVault_Panic();
        }

        if (!evc.isVaultStatusCheckDeferred(address(this))) {
            console.log("EVault Panic on VaultStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (checkedAccount != address(0) && !evc.isAccountStatusCheckDeferred(checkedAccount)) {
            console.log("EVault Panic on AccountStatusCheckDeferred");
            revert EVault_Panic();
        }

        if (controllerEnabled != address(0) && !evc.isControllerEnabled(controllerEnabled, address(this))) {
            console.log("EVault Panic on ControllerEnabled");
            revert EVault_Panic();
        }
    }

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
        checkInvariants(address(0), address(0));
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
        checkInvariants(account, address(0));
    }

    function transferBalance(address from, address to, Shares amount) internal override {
        super.transferBalance(from, to, amount);
        checkInvariants(from, address(0));
    }

    function testExcludeFromCoverage() public pure {}
}

contract EVault_SimpleCriticalChecks is EVaultTestBase {
    EntryPoint entryPoint;
    address[] account_;

    function setUp() public override {
        // Setup

        super.setUp();

        // deploy modified modules
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

        // deploy new EVault implementation with modified modules
        address newEVaultImpl = address(new EVaultOverride(integrations, modules));

        vm.prank(admin);
        factory.setImplementation(newEVaultImpl);

        // deploy new EVault proxies and set up the environment
        eTST = IEVault(factory.createProxy(false, abi.encodePacked(assetTST, oracle, unitOfAccount)));
        eTST.setInterestRateModel(address(new IRMTestDefault()));

        eTST2 = IEVault(factory.createProxy(true, abi.encodePacked(assetTST2, oracle, unitOfAccount)));
        eTST2.setInterestRateModel(address(new IRMTestDefault()));

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0);
        eTST2.setLTV(address(eTST), 0.5e4, 0);

        // accounts

        account_ = new address[](3);
        account_[0] = makeAddr("account0");
        account_[1] = makeAddr("account1");
        account_[2] = makeAddr("account2");

        for (uint256 i = 0; i < account_.length; ++i) {
            assetTST.mint(account_[i], type(uint256).max);
            assetTST2.mint(account_[i], type(uint256).max);

            vm.startPrank(account_[i]);
            assetTST.approve(address(eTST), type(uint256).max);
            assetTST2.approve(address(eTST2), type(uint256).max);
            evc.enableCollateral(account_[i], address(eTST));
            evc.enableCollateral(account_[i], address(eTST2));
            vm.stopPrank();

            targetSender(account_[i]);
        }

        // Fuzzer setup

        IEVault[] memory eTST_ = new IEVault[](2);
        eTST_[0] = eTST;
        eTST_[1] = eTST2;

        entryPoint = new EntryPoint(eTST_, account_);
        targetContract(address(entryPoint));
    }

    function invariant_SimpleCriticalChecks() public view {
        string[] memory errors = entryPoint.getErrors();

        if (errors.length > 0) {
            for (uint256 i = 0; i < errors.length; i++) {
                console.log(errors[i]);
            }
            assertTrue(false);
        }
    }

    function test_ExcludeFromCoverage() public pure {}
}

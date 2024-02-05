// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./shared/Base.sol";
import {TokenModule} from "./modules/Token.sol";
import {ERC4626Module} from "./modules/ERC4626.sol";
import {BorrowingModule} from "./modules/Borrowing.sol";
import {LiquidationModule} from "./modules/Liquidation.sol";
import {FeesModule} from "./modules/Fees.sol";
import {InitializeModule} from "./modules/Initialize.sol";
import {BalanceForwarderModule} from "./modules/BalanceForwarder.sol";
import {ModuleDispatch} from "./modules/ModuleDispatch.sol";
import {GovernanceModule} from "./modules/Governance.sol";
import {RiskManagerModule} from "./modules/RiskManager.sol";

import {IVault} from "ethereum-vault-connector/interfaces/IVault.sol";


contract EVault is
    ModuleDispatch,
    InitializeModule,
    TokenModule,
    ERC4626Module,
    BorrowingModule,
    LiquidationModule,
    FeesModule,
    BalanceForwarderModule,
    GovernanceModule,
    RiskManagerModule
{
    address immutable MODULE_INITIALIZE;
    address immutable MODULE_TOKEN;
    address immutable MODULE_ERC4626;
    address immutable MODULE_BORROWING;
    address immutable MODULE_LIQUIDATION;
    address immutable MODULE_FEES;
    address immutable MODULE_BALANCE_FORWARDER;
    address immutable MODULE_GOVERNANCE;
    address immutable MODULE_RISKMANAGER;

    constructor(
        address evc,
        address protocolAdmin,
        address balanceTracker,
        address MODULE_INITIALIZE_,
        address MODULE_TOKEN_,
        address MODULE_ERC4626_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_FEES_,
        address MODULE_BALANCE_FORWARDER_,
        address MODULE_GOVERNANCE_,
        address MODULE_RISKMANAGER_
    ) Base(evc, protocolAdmin, balanceTracker) {
        MODULE_INITIALIZE = MODULE_INITIALIZE_;
        MODULE_TOKEN = MODULE_TOKEN_;
        MODULE_ERC4626 = MODULE_ERC4626_;
        MODULE_BORROWING = MODULE_BORROWING_;
        MODULE_LIQUIDATION = MODULE_LIQUIDATION_;
        MODULE_FEES = MODULE_FEES_;
        MODULE_BALANCE_FORWARDER = MODULE_BALANCE_FORWARDER_;
        MODULE_GOVERNANCE = MODULE_GOVERNANCE_;
        MODULE_RISKMANAGER = MODULE_RISKMANAGER_;
    }

    // ------------ Initialization -------------

    function initialize(address creator) external override use(MODULE_INITIALIZE) {}



    // ----------------- Token -----------------

    function name() external view override useView(MODULE_TOKEN) returns (string memory) {}

    function symbol() external view override useView(MODULE_TOKEN) returns (string memory) {}

    function decimals() external view override useView(MODULE_TOKEN) returns (uint8) {}

    function totalSupply() external view override useView(MODULE_TOKEN) returns (uint256) {}

    function balanceOf(address account) external view override useView(MODULE_TOKEN) returns (uint256) {}



    function allowance(address holder, address spender) external view override useView(MODULE_TOKEN) returns (uint256) {}

    function transfer(address to, uint256 amount) external override callThroughEVC use(MODULE_TOKEN) returns (bool) {}

    function transferFrom(address from, address to, uint256 amount) public override callThroughEVC use(MODULE_TOKEN) returns (bool) {}

    function approve(address spender, uint256 amount) external override use(MODULE_TOKEN) returns (bool) {}

    function transferFromMax(address from, address to) external override callThroughEVC use(MODULE_TOKEN) returns (bool) {}



    // ----------------- ERC4626 -----------------

    function asset() external view override useView(MODULE_ERC4626) returns (address) {}

    function totalAssets() external view override useView(MODULE_ERC4626) returns (uint256) {}

    function convertToAssets(uint256 shares) public view override useView(MODULE_ERC4626) returns (uint256) {}

    function convertToShares(uint256 assets) public view override useView(MODULE_ERC4626) returns (uint256) {}

    function maxDeposit(address) public view override useView(MODULE_ERC4626) returns (uint256) {}

    function previewDeposit(uint256 assets) external view override useView(MODULE_ERC4626) returns (uint256) {}

    function maxMint(address) external view override useView(MODULE_ERC4626) returns (uint256) {}

    function previewMint(uint256 shares) external view override useView(MODULE_ERC4626) returns (uint256) {}

    function maxWithdraw(address owner) external view override useView(MODULE_ERC4626) returns (uint256) {}

    function previewWithdraw(uint256 assets) external view override useView(MODULE_ERC4626) returns (uint256) {}

    function maxRedeem(address owner) public view override useView(MODULE_ERC4626) returns (uint256) {}

    function previewRedeem(uint256 shares) external view override useView(MODULE_ERC4626) returns (uint256) {}



    function deposit(uint256 assets, address receiver) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    function mint(uint256 shares, address receiver) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    function withdraw(uint256 assets, address receiver, address owner) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    function redeem(uint256 shares, address receiver, address owner) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}



    // ----------------- Borrowing -----------------

    function totalBorrows() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function totalBorrowsExact() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function poolSize() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function debtOf(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    function debtOfExact(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    function interestRate() external view override useView(MODULE_BORROWING) returns (uint72) {}

    function interestAccumulator() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function collateralBalanceLocked(address collateral, address account) external view override useView(MODULE_BORROWING) returns (uint256 lockedBalance) {}

    function dToken() external view override useView(MODULE_BORROWING) returns (address) {}

    function getEVC() external view override useView(MODULE_BORROWING) returns (address) {}



    function borrow(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    function repay(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    function wind(uint256 assets, address collateralReceiver) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function unwind(uint256 assets, address debtFrom) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function pullDebt(uint256 assets, address from) external override callThroughEVC use(MODULE_BORROWING) {}

    function flashLoan(uint256 assets, bytes calldata data) external override use(MODULE_BORROWING) {}

    function touch() external override callThroughEVC use(MODULE_BORROWING) {}



    // ----------------- Liquidation -----------------

    function checkLiquidation(address liquidator, address violator, address collateral) external view override useView(MODULE_LIQUIDATION) returns (uint256 maxRepay, uint256 maxYield) {}

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) external override callThroughEVC use(MODULE_LIQUIDATION) {}



    // ----------------- Fees -----------------

    function feesBalance() external view override useView(MODULE_FEES) returns (uint256) {}

    function feesBalanceUnderlying() external view override useView(MODULE_FEES) returns (uint256) {}

    function interestFee() external view override useView(MODULE_FEES) returns (uint16) {}

    function protocolFeeShare() external view override useView(MODULE_FEES) returns (uint256) {}

    function protocolFeeReceiver() external view override useView(MODULE_FEES) returns (address) {}

    function convertFees() external override callThroughEVC use(MODULE_FEES) {}

    function skimAssets() external override use(MODULE_FEES) {}



    // ----------------- Balance Forwarder -----------------

    function balanceTrackerAddress() external view useView(MODULE_BALANCE_FORWARDER) override returns (address) {}

    function balanceForwarderEnabled(address account) external view useView(MODULE_BALANCE_FORWARDER) override returns (bool) {}

    function enableBalanceForwarder() external override use(MODULE_BALANCE_FORWARDER) {}

    function disableBalanceForwarder() external override use(MODULE_BALANCE_FORWARDER) {}



    // ----------------- Governance -----------------

    function setDefaultInterestRateModel(address newModel) external override use(MODULE_GOVERNANCE) {}

    function setGovernorAdmin(address newGovernorAdmin) external override use(MODULE_GOVERNANCE) {}

    function setFeeReceiver(address newFeeReceiver) external override use(MODULE_GOVERNANCE) {}

    function setLTV(address collateral, uint16 collateralFactor, uint256 ramp) external override use(MODULE_GOVERNANCE) {}

    function setIRM(address newModel, bytes calldata resetParams) external override use(MODULE_GOVERNANCE) {}

    function setOracle(address newOracle) external override use(MODULE_GOVERNANCE) {}

    function setMarketPolicy(uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) external override use(MODULE_GOVERNANCE) {}

    function setInterestFee(uint16 newFee) external override use(MODULE_GOVERNANCE) {}

    function setUnitOfAccount(address newUnitOfAccount) external override use(MODULE_GOVERNANCE) {}

    function getGovernorAdmin() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function getLTV(address collateral) external override useView(MODULE_GOVERNANCE) view returns (LTVConfig memory) {}

    function getLTVList() external override useView(MODULE_GOVERNANCE) view returns (address[] memory) {}

    function interestRateModel() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function getDefaultInterestRateModel() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function getMarketPolicy() external override useView(MODULE_GOVERNANCE) view returns (uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) {}

    function feeReceiver() external override useView(MODULE_GOVERNANCE) view returns (address) {}



    // ----------------- RiskManager -----------------

    function disableController() external override use(MODULE_RISKMANAGER) {}

    function checkAccountStatus(address account, address[] calldata collaterals) external override use(MODULE_RISKMANAGER) returns (bytes4) {}

    function checkVaultStatus() external override use(MODULE_RISKMANAGER) returns (bytes4) {}

    function computeAccountLiquidity(address account) external override view useView(MODULE_RISKMANAGER) returns (uint256 collateralValue, uint256 liabilityValue) {}

    function computeAccountLiquidityPerMarket(address account) external override view useView(MODULE_RISKMANAGER) returns (MarketLiquidity[] memory) {}
}

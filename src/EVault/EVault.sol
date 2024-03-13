// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Dispatch} from "./modules/Dispatch.sol";

contract EVault is Dispatch {
    constructor(Integrations memory integrations, DeployedModules memory modules) Dispatch(integrations, modules) {}


    // ------------ Initialization -------------

    function initialize(address proxyCreator) external override use(MODULE_INITIALIZE) {}



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



    // ----------------- Vault -----------------

    function asset() external view override useView(MODULE_VAULT) returns (address) {}

    function totalAssets() external view override useView(MODULE_VAULT) returns (uint256) {}

    function convertToAssets(uint256 shares) public view override useView(MODULE_VAULT) returns (uint256) {}

    function convertToShares(uint256 assets) public view override useView(MODULE_VAULT) returns (uint256) {}

    function maxDeposit(address) public view override useView(MODULE_VAULT) returns (uint256) {}

    function previewDeposit(uint256 assets) external view override useView(MODULE_VAULT) returns (uint256) {}

    function maxMint(address) external view override useView(MODULE_VAULT) returns (uint256) {}

    function previewMint(uint256 shares) external view override useView(MODULE_VAULT) returns (uint256) {}

    function maxWithdraw(address owner) external view override useView(MODULE_VAULT) returns (uint256) {}

    function previewWithdraw(uint256 assets) external view override useView(MODULE_VAULT) returns (uint256) {}

    function maxRedeem(address owner) public view override useView(MODULE_VAULT) returns (uint256) {}

    function previewRedeem(uint256 shares) external view override useView(MODULE_VAULT) returns (uint256) {}

    function accumulatedFees() external view override useView(MODULE_VAULT) returns (uint256) {}

    function accumulatedFeesAssets() external view override useView(MODULE_VAULT) returns (uint256) {}

    function creator() external view override useView(MODULE_VAULT) returns (address) {}


    function deposit(uint256 assets, address receiver) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function mint(uint256 shares, address receiver) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function withdraw(uint256 assets, address receiver, address owner) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function redeem(uint256 shares, address receiver, address owner) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function skim(uint256 assets, address receiver) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {}



    // ----------------- Borrowing -----------------

    function totalBorrows() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function totalBorrowsExact() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function cash() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function debtOf(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    function debtOfExact(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    function interestRate() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function interestAccumulator() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function collateralUsed(address collateral, address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    function dToken() external view override useView(MODULE_BORROWING) returns (address) {}


    function borrow(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    function repay(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    function loop(uint256 assets, address sharesReceiver) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function deloop(uint256 assets, address debtFrom) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function pullDebt(uint256 assets, address from) external override callThroughEVC use(MODULE_BORROWING) {}

    function flashLoan(uint256 assets, bytes calldata data) external override use(MODULE_BORROWING) {}

    function touch() external override callThroughEVC use(MODULE_BORROWING) {}



    // ----------------- Liquidation -----------------

    function checkLiquidation(address liquidator, address violator, address collateral) external view override useView(MODULE_LIQUIDATION) returns (uint256 maxRepay, uint256 maxYield) {}

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) external override callThroughEVC use(MODULE_LIQUIDATION) {}



    // ----------------- RiskManager -----------------

    function accountLiquidity(address account, bool liquidation) external view override useView(MODULE_RISKMANAGER) returns (uint256 collateralValue, uint256 liabilityValue) {}

    function accountLiquidityFull(address account, bool liquidation) external view override useView(MODULE_RISKMANAGER) returns (address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue) {}


    function disableController() external override use(MODULE_RISKMANAGER) {}

    function checkAccountStatus(address account, address[] calldata collaterals) external override use(MODULE_RISKMANAGER) returns (bytes4) {}

    function checkVaultStatus() external override use(MODULE_RISKMANAGER) returns (bytes4) {}



    // ----------------- Balance Forwarder -----------------

    function balanceTrackerAddress() external view useView(MODULE_BALANCE_FORWARDER) override returns (address) {}

    function balanceForwarderEnabled(address account) external view useView(MODULE_BALANCE_FORWARDER) override returns (bool) {}


    function enableBalanceForwarder() external override use(MODULE_BALANCE_FORWARDER) {}

    function disableBalanceForwarder() external override use(MODULE_BALANCE_FORWARDER) {}



    // ----------------- Governance -----------------

    function governorAdmin() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function pauseGuardian() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function interestFee() external override useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function protocolConfigAddress() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function protocolFeeShare() external override useView(MODULE_GOVERNANCE) view returns (uint256) {}

    function protocolFeeReceiver() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function borrowingLTV(address collateral) external override useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function liquidationLTV(address collateral) external override useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function LTVFull(address collateral) external override useView(MODULE_GOVERNANCE) view returns (uint48 targetTimestamp, uint16 targetLTV, uint32 rampDuration, uint16 originalLTV) {}

    function LTVList() external override useView(MODULE_GOVERNANCE) view returns (address[] memory) {}

    function interestRateModel() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function disabledOps() external override useView(MODULE_GOVERNANCE) view returns (uint32) {}

    function caps() external override useView(MODULE_GOVERNANCE) view returns (uint16 supplyCap, uint16 borrowCap) {}

    function feeReceiver() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function EVC() external view override useView(MODULE_GOVERNANCE) returns (address) {}

    function permit2Address() external view override useView(MODULE_GOVERNANCE) returns (address) {}

    function unitOfAccount() external override useView(MODULE_GOVERNANCE) view returns (address) {}

    function oracle() external override useView(MODULE_GOVERNANCE) view returns (address) {}


    function convertFees() external override callThroughEVC use(MODULE_GOVERNANCE) {}

    function setName(string calldata newName) external override use(MODULE_GOVERNANCE) {}

    function setSymbol(string calldata newName) external override use(MODULE_GOVERNANCE) {}

    function setGovernorAdmin(address newGovernorAdmin) external override use(MODULE_GOVERNANCE) {}

    function setPauseGuardian(address newGovernorAdmin) external override use(MODULE_GOVERNANCE) {}

    function setFeeReceiver(address newFeeReceiver) external override use(MODULE_GOVERNANCE) {}

    function setLTV(address collateral, uint16 ltv, uint32 rampDuration) external override use(MODULE_GOVERNANCE) {}

    function clearLTV(address collateral) external override use(MODULE_GOVERNANCE) {}

    function setIRM(address newModel) external override use(MODULE_GOVERNANCE) {}

    function setDisabledOps(uint32 newDisabledOps) external override use(MODULE_GOVERNANCE) {}

    function setCaps(uint16 supplyCap, uint16 borrowCap) external override use(MODULE_GOVERNANCE) {}

    function setInterestFee(uint16 newFee) external override use(MODULE_GOVERNANCE) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Dispatch} from "./modules/Dispatch.sol";

contract EVault is Dispatch {
    constructor(Integrations memory integrations, DeployedModules memory modules) Dispatch(integrations, modules) {}


    // ------------ Initialization -------------

    function initialize(address proxyCreator) public override virtual use(MODULE_INITIALIZE) {}



    // ----------------- Token -----------------

    function name() public view override virtual useView(MODULE_TOKEN) returns (string memory) {}

    function symbol() public view override virtual useView(MODULE_TOKEN) returns (string memory) {}

    function decimals() public view override virtual useView(MODULE_TOKEN) returns (uint8) {}

    function totalSupply() public view override virtual useView(MODULE_TOKEN) returns (uint256) {}

    function balanceOf(address account) public view override virtual returns (uint256) { return super.balanceOf(account); }

    function allowance(address holder, address spender) public view override virtual returns (uint256) { return super.allowance(holder, spender); }


    function transfer(address to, uint256 amount) public override virtual callThroughEVC returns (bool) { return super.transfer(to, amount); }

    function transferFrom(address from, address to, uint256 amount) public override virtual callThroughEVC returns (bool) { return super.transferFrom(from, to, amount); }

    function approve(address spender, uint256 amount) public override virtual returns (bool) { return super.approve(spender, amount); }

    function transferFromMax(address from, address to) public override virtual callThroughEVC returns (bool) { return super.transferFromMax(from, to); }



    // ----------------- Vault -----------------

    function asset() public view override virtual returns (address) { return super.asset(); }

    function totalAssets() public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function convertToAssets(uint256 shares) public view override virtual returns (uint256) { return super.convertToAssets(shares); }

    function convertToShares(uint256 assets) public view override virtual returns (uint256) { return super.convertToShares(assets); }

    function maxDeposit(address account) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function previewDeposit(uint256 assets) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function maxMint(address account) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function previewMint(uint256 shares) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function maxWithdraw(address owner) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function previewWithdraw(uint256 assets) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function maxRedeem(address owner) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function previewRedeem(uint256 shares) public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function accumulatedFees() public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function accumulatedFeesAssets() public view override virtual useView(MODULE_VAULT) returns (uint256) {}

    function creator() public view override virtual useView(MODULE_VAULT) returns (address) {}


    function deposit(uint256 amount, address receiver) public override virtual callThroughEVC returns (uint256) { return super.deposit(amount, receiver); }

    function mint(uint256 amount, address receiver) public override virtual callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function withdraw(uint256 amount, address receiver, address owner) public override virtual callThroughEVC returns (uint256) { return super.withdraw(amount, receiver, owner); }

    function redeem(uint256 amount, address receiver, address owner) public override virtual callThroughEVC use(MODULE_VAULT) returns (uint256) {}

    function skim(uint256 amount, address receiver) public override virtual callThroughEVC use(MODULE_VAULT) returns (uint256) {}



    // ----------------- Borrowing -----------------

    function totalBorrows() public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function totalBorrowsExact() public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function cash() public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function debtOf(address account) public view override virtual returns (uint256) { return super.debtOf(account); }

    function debtOfExact(address account) public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function interestRate() public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function interestAccumulator() public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function collateralUsed(address collateral, address account) public view override virtual useView(MODULE_BORROWING) returns (uint256) {}

    function dToken() public view override virtual useView(MODULE_BORROWING) returns (address) {}


    function borrow(uint256 amount, address receiver) public override virtual callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function repay(uint256 amount, address receiver) public override virtual callThroughEVC use(MODULE_BORROWING) returns (uint256) {} 

    function loop(uint256 amount, address sharesReceiver) public override virtual callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function deloop(uint256 amount, address debtFrom) public override virtual callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function pullDebt(uint256 amount, address from) public override virtual callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    function flashLoan(uint256 amount, bytes calldata data) public override virtual use(MODULE_BORROWING) {}

    function touch() public override virtual callThroughEVC use(MODULE_BORROWING) {}



    // ----------------- Liquidation -----------------

    function checkLiquidation(address liquidator, address violator, address collateral) public view override virtual useView(MODULE_LIQUIDATION) returns (uint256 maxRepay, uint256 maxYield) {}

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) public override virtual callThroughEVC use(MODULE_LIQUIDATION) {}



    // ----------------- RiskManager -----------------

    function accountLiquidity(address account, bool liquidation) public view override virtual useView(MODULE_RISKMANAGER) returns (uint256 collateralValue, uint256 liabilityValue) {}

    function accountLiquidityFull(address account, bool liquidation) public view override virtual useView(MODULE_RISKMANAGER) returns (address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue) {}


    function disableController() public override virtual use(MODULE_RISKMANAGER) {}

    function checkAccountStatus(address account, address[] calldata collaterals) public override virtual returns (bytes4) { return super.checkAccountStatus(account, collaterals); }

    function checkVaultStatus() public override virtual returns (bytes4) { return super.checkVaultStatus(); }



    // ----------------- Balance Forwarder -----------------

    function balanceTrackerAddress() public view override virtual useView(MODULE_BALANCE_FORWARDER) returns (address) {}

    function balanceForwarderEnabled(address account) public view override virtual useView(MODULE_BALANCE_FORWARDER) returns (bool) {}


    function enableBalanceForwarder() public override virtual use(MODULE_BALANCE_FORWARDER) {}

    function disableBalanceForwarder() public override virtual use(MODULE_BALANCE_FORWARDER) {}



    // ----------------- Governance -----------------

    function governorAdmin() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function pauseGuardian() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function interestFee() public override virtual useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function protocolConfigAddress() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function protocolFeeShare() public override virtual useView(MODULE_GOVERNANCE) view returns (uint256) {}

    function protocolFeeReceiver() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function borrowingLTV(address collateral) public override virtual useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function liquidationLTV(address collateral) public override virtual useView(MODULE_GOVERNANCE) view returns (uint16) {}

    function LTVFull(address collateral) public override virtual useView(MODULE_GOVERNANCE) view returns (uint48 targetTimestamp, uint16 targetLTV, uint32 rampDuration, uint16 originalLTV) {}

    function LTVList() public override virtual useView(MODULE_GOVERNANCE) view returns (address[] memory) {}

    function interestRateModel() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function disabledOps() public override virtual useView(MODULE_GOVERNANCE) view returns (uint32) {}

    function caps() public override virtual useView(MODULE_GOVERNANCE) view returns (uint16 supplyCap, uint16 borrowCap) {}

    function feeReceiver() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function EVC() public view override virtual useView(MODULE_GOVERNANCE) returns (address) {}

    function permit2Address() public view override virtual useView(MODULE_GOVERNANCE) returns (address) {}

    function unitOfAccount() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}

    function oracle() public override virtual useView(MODULE_GOVERNANCE) view returns (address) {}


    function convertFees() public override virtual callThroughEVC use(MODULE_GOVERNANCE) {}

    function setName(string calldata newName) public override virtual use(MODULE_GOVERNANCE) {}

    function setSymbol(string calldata newSymbol) public override virtual use(MODULE_GOVERNANCE) {}

    function setGovernorAdmin(address newGovernorAdmin) public override virtual use(MODULE_GOVERNANCE) {}

    function setPauseGuardian(address newPauseGuardian) public override virtual use(MODULE_GOVERNANCE) {}

    function setFeeReceiver(address newFeeReceiver) public override virtual use(MODULE_GOVERNANCE) {}

    function setLTV(address collateral, uint16 ltv, uint32 rampDuration) public override virtual use(MODULE_GOVERNANCE) {}

    function clearLTV(address collateral) public override virtual use(MODULE_GOVERNANCE) {}

    function setIRM(address newModel) public override virtual use(MODULE_GOVERNANCE) {}

    function setDisabledOps(uint32 newDisabledOps) public override virtual use(MODULE_GOVERNANCE) {}

    function setCaps(uint16 supplyCap, uint16 borrowCap) public override virtual use(MODULE_GOVERNANCE) {}

    function setInterestFee(uint16 newFee) public override virtual use(MODULE_GOVERNANCE) {}
}

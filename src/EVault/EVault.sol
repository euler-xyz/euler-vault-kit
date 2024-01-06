// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./shared/Base.sol";
import {TokenModule} from "./modules/Token.sol";
import {ERC4626Module} from "./modules/ERC4626.sol";
import {BorrowingModule} from "./modules/Borrowing.sol";
import {LiquidationModule} from "./modules/Liquidation.sol";
import {FeesModule} from "./modules/Fees.sol";
import {InitializeModule} from "./modules/Initialize.sol";
import {ModuleDispatch} from "./modules/ModuleDispatch.sol";

contract EVault is
    ModuleDispatch,
    InitializeModule,
    TokenModule,
    ERC4626Module,
    BorrowingModule,
    LiquidationModule,
    FeesModule
{
    address immutable MODULE_INITIALIZE;
    address immutable MODULE_TOKEN;
    address immutable MODULE_ERC4626;
    address immutable MODULE_BORROWING;
    address immutable MODULE_LIQUIDATION;
    address immutable MODULE_FEES;

    constructor(
        address evc,
        address MODULE_INITIALIZE_,
        address MODULE_TOKEN_,
        address MODULE_ERC4626_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_FEES_
    ) Base(evc) {
        MODULE_INITIALIZE = MODULE_INITIALIZE_;
        MODULE_TOKEN = MODULE_TOKEN_;
        MODULE_ERC4626 = MODULE_ERC4626_;
        MODULE_BORROWING = MODULE_BORROWING_;
        MODULE_LIQUIDATION = MODULE_LIQUIDATION_;
        MODULE_FEES = MODULE_FEES_;
    }

    // ------------ Initialization -------------

    function initialize(address creator) external override use(MODULE_INITIALIZE) {}



    // ----------------- Token -----------------

    function name() external view override useView(MODULE_TOKEN) returns (string memory) {}

    function symbol() external view override useView(MODULE_TOKEN) returns (string memory) {}

    function decimals() external view override useView(MODULE_TOKEN) returns (uint8) {}

    function totalSupply() external view override useView(MODULE_TOKEN) returns (uint256) {}

    // function balanceOf(address account) external view override useView(MODULE_TOKEN) returns (uint256) {}



    // function allowance(address holder, address spender) external view override useView(MODULE_TOKEN) returns (uint256) {}

    // function transfer(address to, uint256 amount) external override callThroughEVC use(MODULE_TOKEN) returns (bool) {}

    // function transferFrom(address from, address to, uint256 amount) public override callThroughEVC use(MODULE_TOKEN) returns (bool) {}

    // function approve(address spender, uint256 amount) external override use(MODULE_TOKEN) returns (bool) {}

    // function transferFromMax(address from, address to) external override callThroughEVC use(MODULE_TOKEN) returns (bool) {}



    // ----------------- ERC4626 -----------------

    function asset() external view override useView(MODULE_ERC4626) returns (address) {}

    function totalAssets() external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function convertToAssets(uint256 shares) public view override useView(MODULE_ERC4626) returns (uint256) {}

    // function convertToShares(uint256 assets) public view override useView(MODULE_ERC4626) returns (uint256) {}

    // function maxDeposit(address) public view override useView(MODULE_ERC4626) returns (uint256) {}

    // function previewDeposit(uint256 assets) external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function maxMint(address) external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function previewMint(uint256 shares) external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function maxWithdraw(address owner) external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function previewWithdraw(uint256 assets) external view override useView(MODULE_ERC4626) returns (uint256) {}

    // function maxRedeem(address owner) public view override useView(MODULE_ERC4626) returns (uint256) {}

    // function previewRedeem(uint256 shares) external view override useView(MODULE_ERC4626) returns (uint256) {}



    function deposit(uint256 assets, address receiver) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    // function mint(uint256 shares, address receiver) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    // function withdraw(uint256 assets, address receiver, address owner) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}

    // function redeem(uint256 shares, address receiver, address owner) external override callThroughEVC use(MODULE_ERC4626) returns (uint256) {}



    // ----------------- Borrowing -----------------

    function totalBorrows() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function totalBorrowsExact() external view override useView(MODULE_BORROWING) returns (uint256) {}

    // function poolSize() external view override useView(MODULE_BORROWING) returns (uint256) {}

    function debtOf(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    // function debtOfExact(address account) external view override useView(MODULE_BORROWING) returns (uint256) {}

    // function interestRate() external view override useView(MODULE_BORROWING) returns (int96) {}

    // function interestAccumulator() external view override useView(MODULE_BORROWING) returns (uint256) {}

    // function collateralBalanceLocked(address collateral, address account) external view override useView(MODULE_BORROWING) returns (uint256 lockedBalance) {}

    // function riskManager() external view override useView(MODULE_BORROWING) returns (address) {}

    // function dToken() external view override useView(MODULE_BORROWING) returns (address) {}

    // function getEVC() external view override useView(MODULE_BORROWING) returns (address) {}



    // function borrow(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    // function repay(uint256 assets, address receiver) external override callThroughEVC use(MODULE_BORROWING) {}

    // function wind(uint256 assets, address collateralReceiver) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    // function unwind(uint256 assets, address debtFrom) external override callThroughEVC use(MODULE_BORROWING) returns (uint256) {}

    // function pullDebt(uint256 assets, address from) external override callThroughEVC use(MODULE_BORROWING) {}

    // function flashLoan(uint256 assets, bytes calldata data) external override use(MODULE_BORROWING) {}

    // function touch() external override callThroughEVC use(MODULE_BORROWING) {}

    // function disableController() external override use(MODULE_BORROWING) {}

    // function checkAccountStatus(address account, address[] calldata collaterals) public override returns (bytes4) {
    //     return super.checkAccountStatus(account, collaterals);
    // }

    function checkVaultStatus() public override returns (bytes4) {
        return super.checkVaultStatus();
    }



    // ----------------- Liquidation -----------------

    // function checkLiquidation(address liquidator, address violator, address collateral) external view override useView(MODULE_LIQUIDATION) returns (uint256 maxRepay, uint256 maxYield) {}

    // function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) external override callThroughEVC use(MODULE_LIQUIDATION) {}



    // ----------------- Fees -----------------

    // function feesBalance() external view override useView(MODULE_FEES) returns (uint256) {}

    // function feesBalanceUnderlying() external view override useView(MODULE_FEES) returns (uint256) {}

    // function interestFee() external view override useView(MODULE_FEES) returns (uint16) {}

    // function protocolFeeShare() external view override useView(MODULE_FEES) returns (uint256) {}

    // function protocolFeesHolder() external view override useView(MODULE_FEES) returns (address) {}

    // function setProtocolFeesHolder(address newHolder) external override use(MODULE_FEES) {}

    // function convertFees() external override callThroughEVC use(MODULE_FEES) {}
}

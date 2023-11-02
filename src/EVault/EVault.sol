// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./shared/Base.sol";
import {DToken} from "./DToken.sol";
import {ERC20Module} from "./modules/ERC20.sol";
import {ERC4626Module} from "./modules/ERC4626.sol";
import {BorrowingModule} from "./modules/Borrowing.sol";
import {LiquidationModule} from "./modules/Liquidation.sol";
import {AdminModule} from "./modules/Admin.sol";

import "./shared/Constants.sol";

contract EVault is ERC20Module, ERC4626Module, BorrowingModule, LiquidationModule, AdminModule {
    address immutable MODULE_ERC20;
    address immutable MODULE_ERC4626;
    address immutable MODULE_BORROWING;
    address immutable MODULE_LIQUIDATION;
    address immutable MODULE_ADMIN;

    constructor(
        address factory,
        address cvc,
        address MODULE_ERC20_,
        address MODULE_ERC4626_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_ADMIN_
    ) Base(factory, cvc) {
        MODULE_ERC20 = MODULE_ERC20_;
        MODULE_ERC4626 = MODULE_ERC4626_;
        MODULE_BORROWING = MODULE_BORROWING_;
        MODULE_LIQUIDATION = MODULE_LIQUIDATION_;
        MODULE_ADMIN = MODULE_ADMIN_;
    }

    function initialize() external {
        if (msg.sender != factory) revert E_Unauthorized();
        if (marketStorage.lastInterestAccumulatorUpdate != 0) revert E_Initialized();

        marketStorage.lastInterestAccumulatorUpdate = uint40(block.timestamp);
        marketStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;
        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        address dTokenAddress = address(new DToken()); // TODO deploy from module to free up code space

        emit DTokenCreated(dTokenAddress);
    }


    // ----------------- ERC20 -----------------


    function name() external view useView(MODULE_ERC20) override returns (string memory) {}

    function symbol() external view useView(MODULE_ERC20) override returns (string memory) {}

    function decimals() external view useView(MODULE_ERC20) override returns (uint8) {}

    function totalSupply() external view useView(MODULE_ERC20) override returns (uint) {}

    // function balanceOf(address account) external view useView(MODULE_ERC20) override returns (uint) {}

    // function allowance(address holder, address spender) external view useView(MODULE_ERC20) override returns (uint) {}



    // function transfer(address to, uint amount) external use(MODULE_ERC20) override returns (bool) {}

    // function transferFromMax(address from, address to) external use(MODULE_ERC20) override returns (bool) {}

    // function transferFrom(address from, address to, uint amount) public use(MODULE_ERC20) override returns (bool) {}

    // function approve(address spender, uint amount) external use(MODULE_ERC20) override returns (bool) {}


    // // ----------------- ERC4626 -----------------


    function asset() external view useView(MODULE_ERC4626) override returns (address) {}

    function totalAssets() external view useView(MODULE_ERC4626) override returns (uint) {}

    // function convertToAssets(uint shares) public view useView(MODULE_ERC4626) override returns (uint) {}

    // function convertToShares(uint assets) public view useView(MODULE_ERC4626) override returns (uint) {}

    // function maxDeposit(address) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function previewDeposit(uint assets) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function maxMint(address) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function previewMint(uint shares) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function maxWithdraw(address owner) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function previewWithdraw(uint assets) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function maxRedeem(address owner) external view useView(MODULE_ERC4626) override returns (uint) {}

    // function previewRedeem(uint shares) external view useView(MODULE_ERC4626) override returns (uint) {}



    function deposit(uint assets, address receiver) external use(MODULE_ERC4626) override returns (uint) {}

    // function mint(uint shares, address receiver) external use(MODULE_ERC4626) override returns (uint) {}

    // function withdraw(uint assets, address receiver, address owner) external use(MODULE_ERC4626)  override returns (uint) {}

    // function redeem(uint shares, address receiver, address owner) external use(MODULE_ERC4626) override returns (uint) {}



    // // ----------------- Lending -----------------



    function totalBorrows() external view useView(MODULE_BORROWING) override returns (uint) {}

    function totalBorrowsExact() external view useView(MODULE_BORROWING) override returns (uint) {}

    function debtOf(address account) external view useView(MODULE_BORROWING) override returns (uint) {}

    // function debtOfExact(address account) external view useView(MODULE_BORROWING) override returns (uint) {}

    // function interestRate() external view useView(MODULE_BORROWING) override returns (int96) {}

    // function interestAccumulator() external view useView(MODULE_BORROWING) override returns (uint) {}

    // function riskManager() external view useView(MODULE_BORROWING) override returns (address) {}

    // function dToken() external useView(MODULE_BORROWING) override view returns (address) {}

    // function getCVC() external useView(MODULE_BORROWING) override view returns (address) {}


    // function borrow(uint assets, address receiver) external use(MODULE_BORROWING) override {}

    // function repay(uint assets, address receiver) external use(MODULE_BORROWING) override {}

    // function wind(uint assets, address collateralReceiver) external use(MODULE_BORROWING) override returns (uint) {}

    // function unwind(uint assets, address debtFrom) external use(MODULE_BORROWING) override returns (uint) {}

    // function pullDebt(uint assets, address from) external use(MODULE_BORROWING) override returns (bool) {}

    // function flashLoan(uint assets, bytes calldata data) external use(MODULE_BORROWING) override {}

    // function touch() external use(MODULE_BORROWING) override {}

    // function donateToReserves(uint shares) external use(MODULE_BORROWING) override {}

    // function releaseController() external use(MODULE_BORROWING) override {}

    // function checkAccountStatus(address account, address[] calldata collaterals)
    //     external use(MODULE_BORROWING) override returns (bytes4) {}

    // function checkVaultStatus() external use(MODULE_BORROWING) override returns (bytes4) {}


    // // ----------------- Liquidation -----------------


    // function checkLiquidation(address liquidator, address violator, address collateral)
    //     external view useView(MODULE_LIQUIDATION) override returns (uint maxRepay, uint maxYield) {}

    // function liquidate(address violator, address collateral, uint repayAssets, uint minYieldBalance)
    //     external use(MODULE_LIQUIDATION) override {}



    // // ----------------- Admin -----------------



    // function feesBalance() external view useView(MODULE_ADMIN) override returns (uint) {}

    // function feesBalanceUnderlying() external view useView(MODULE_ADMIN) override returns (uint) {}

    // function interestFee() external view useView(MODULE_ADMIN) override returns (uint16) {}

    // function protocolFeeShare() external view useView(MODULE_ADMIN) override returns (uint) {}

    // function convertFees() external use(MODULE_ADMIN) override {}



    // ----------------- DISPATCH -----------------



    modifier use(address module) {
        _;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    modifier useView(address module) {
        _;
        ViewDelegate(address(this)).viewDelegate(module, msg.data);
        assembly {
            returndatacopy(0, 0, returndatasize())
            return(0, returndatasize())
        }
    }

    function viewDelegate(address module, bytes calldata payload) external {
        if (msg.sender != address(this)) revert ("unauthorized");
        (bool result, ) = module.delegatecall(payload);

        assembly {
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

interface ViewDelegate {
    function viewDelegate(address, bytes memory) external view;
}
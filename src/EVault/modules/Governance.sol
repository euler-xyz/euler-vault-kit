// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {IPriceOracle} from "../../IPriceOracle.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base, BalanceUtils {
    using TypesLib for uint16;

    event GovSetName(string newName);
    event GovSetSymbol(string newSymbol);
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetPauseGuardian(address newPauseGuardian);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetLTV(address indexed collateral, uint40 targetTimestamp, uint16 targetLTV, uint24 rampDuration, uint16 originalLTV);
    event GovSetIRM(address interestRateModel, bytes resetParams);
    event GovSetDisabledOps(uint32 newDisabledOps);
    event GovSetCaps(uint16 newSupplyCap, uint16 newBorrowCap);
    event GovSetInterestFee(uint16 newFee);
    event GovSetDebtSocialization(bool debtSocialization);

    modifier governorOnly() {
        if (msg.sender != marketStorage.governorAdmin) revert E_Unauthorized();
        _;
    }

    modifier pauseGuardianOnly() {
        if (msg.sender != marketStorage.pauseGuardian) revert E_Unauthorized();
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() external view virtual reentrantOK returns (address) {
        return marketStorage.governorAdmin;
    }

    /// @inheritdoc IGovernance
    function pauseGuardian() external view virtual reentrantOK returns (address) {
        return marketStorage.pauseGuardian;
    }

    /// @inheritdoc IGovernance
    function interestFee() external view virtual reentrantOK returns (uint16) {
        return marketStorage.interestFee.toUint16();
    }

    /// @inheritdoc IGovernance
    function protocolFeeShare() external view virtual reentrantOK returns (uint256) {
        (, uint256 protocolShare) = protocolConfig.feeConfig(address(this));
        return protocolShare;
    }

    /// @inheritdoc IGovernance
    function protocolFeeReceiver() external view virtual reentrantOK returns (address) {
        (address protocolReceiver,) = protocolConfig.feeConfig(address(this));
        return protocolReceiver;
    }

    /// @inheritdoc IGovernance
    function LTV(address collateral) external view virtual reentrantOK returns (uint16) {
        return ltvLookup[collateral].getLTV().toUint16();
    }

    /// @inheritdoc IGovernance
    function LTVLiquidation(address collateral) external view virtual reentrantOK returns (uint16) {
        return ltvLookup[collateral].getLiquidationLTV().toUint16();
    }

    /// @inheritdoc IGovernance
    function LTVFull(address collateral) external view virtual reentrantOK returns (uint40, uint16, uint24, uint16) {
        LTVConfig memory ltv = ltvLookup[collateral];
        return (
            ltv.targetTimestamp,
            ltv.targetLTV.toUint16(),
            ltv.rampDuration,
            ltv.originalLTV.toUint16()
        );
    }

    /// @inheritdoc IGovernance
    function LTVList() external view virtual reentrantOK returns (address[] memory) {
        return ltvList;
    }

    /// @inheritdoc IGovernance
    function interestRateModel() external view virtual reentrantOK returns (address) {
        return marketStorage.interestRateModel;
    }

    /// @inheritdoc IGovernance
    function disabledOps() external view virtual reentrantOK returns (uint32) {
        return (marketStorage.disabledOps.toUint32());
    }

    /// @inheritdoc IGovernance
    function caps() external view virtual reentrantOK returns (uint16, uint16) {
        return (marketStorage.supplyCap.toRawUint16(), marketStorage.borrowCap.toRawUint16());
    }

    /// @inheritdoc IGovernance
    function feeReceiver() external view virtual reentrantOK returns (address) {
        return marketStorage.feeReceiver;
    }

    /// @inheritdoc IGovernance
    function debtSocialization() external view virtual reentrantOK returns (bool) {
        return marketStorage.debtSocialization;
    }

    /// @inheritdoc IGovernance
    function unitOfAccount() external view virtual reentrantOK returns (address) {
        (,, address _unitOfAccount) = ProxyUtils.metadata();
        return _unitOfAccount;
    }

    /// @inheritdoc IGovernance
    function oracle() external view virtual reentrantOK returns (address) {
        (, IPriceOracle _oracle,) = ProxyUtils.metadata();
        return address(_oracle);
    }

     /// @inheritdoc IGovernance
    function convertFees() external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, ACCOUNTCHECK_NONE);

        if (marketCache.feesBalance.isZero()) return;

        // Decrease totalShares because increaseBalance will increase it by that total amount
        marketStorage.totalShares =
            marketCache.totalShares = marketCache.totalShares - marketCache.feesBalance;

        (address protocolReceiver, uint256 protocolFee) = protocolConfig.feeConfig(address(this));
        address governorReceiver = marketStorage.feeReceiver;

        if (governorReceiver == address(0)) protocolFee = 1e18; // governor forfeits fees
        else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) protocolFee = MAX_PROTOCOL_FEE_SHARE;


        Shares governorShares = marketCache.feesBalance.mulDiv(1e18 - protocolFee, 1e18);
        Shares protocolShares = marketCache.feesBalance - governorShares;

        marketStorage.feesBalance = marketCache.feesBalance = Shares.wrap(0);

        Assets governorAssets = governorShares.toAssetsDown(marketCache);
        Assets protocolAssets = protocolShares.toAssetsDown(marketCache);

        increaseBalance(
            marketCache, governorReceiver, address(0), governorShares, governorAssets
        ); // TODO confirm address(0)
        increaseBalance(
            marketCache, protocolReceiver, address(0), protocolShares, protocolAssets
        );

        emit ConvertFees(
            account,
            protocolReceiver,
            governorReceiver,
            protocolAssets.toUint(),
            governorAssets.toUint()
        );
    }

    /// @inheritdoc IGovernance
    function setName(string calldata newName) external virtual nonReentrant governorOnly {
        marketStorage.name = newName;
        emit GovSetName(newName);
    }

    /// @inheritdoc IGovernance
    function setSymbol(string calldata newSymbol) external virtual nonReentrant governorOnly {
        marketStorage.symbol = newSymbol;
        emit GovSetSymbol(newSymbol);
    }

    /// @inheritdoc IGovernance
    function setGovernorAdmin(address newGovernorAdmin) external virtual nonReentrant governorOnly {
        marketStorage.governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @inheritdoc IGovernance
    function setPauseGuardian(address newPauseGuardian) external virtual nonReentrant governorOnly {
        marketStorage.pauseGuardian = newPauseGuardian;
        emit GovSetPauseGuardian(newPauseGuardian);
    }

    /// @inheritdoc IGovernance
    function setFeeReceiver(address newFeeReceiver) external virtual nonReentrant governorOnly {
        marketStorage.feeReceiver = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    /// @inheritdoc IGovernance
    function setLTV(address collateral, uint16 ltv, uint24 rampDuration) external virtual nonReentrant governorOnly {
        // self-collateralization is not allowed
        if (collateral == address(this)) revert E_InvalidLTVAsset();

        LTVConfig memory origLTV = ltvLookup[collateral];
        LTVConfig memory newLTV = origLTV.setLTV(ltv.toConfigAmount(), rampDuration);

        ltvLookup[collateral] = newLTV;

        if (!origLTV.initialised()) ltvList.push(collateral);

        emit GovSetLTV(collateral, newLTV.targetTimestamp, newLTV.targetLTV.toUint16(), newLTV.rampDuration, newLTV.originalLTV.toUint16());
    }

    /// @inheritdoc IGovernance
    function clearLTV(address collateral) external virtual nonReentrant governorOnly {
        uint16 originalLTV = ltvLookup[collateral].getLiquidationLTV().toUint16();
        ltvLookup[collateral].clear();

        emit GovSetLTV(collateral, 0, 0, 0, originalLTV);
    }

    /// @inheritdoc IGovernance
    function setIRM(address newModel, bytes calldata resetParams) external virtual nonReentrant governorOnly {
        // TODO IIRM reset ?

        marketStorage.interestRateModel = newModel;

        emit GovSetIRM(newModel, resetParams);
    }

    /// @inheritdoc IGovernance
    function setDisabledOps(uint32 newDisabledOps) external virtual nonReentrant pauseGuardianOnly {
        marketStorage.disabledOps = DisabledOps.wrap(newDisabledOps);
        emit GovSetDisabledOps(newDisabledOps);
    }

    /// @inheritdoc IGovernance
    function setCaps(uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        AmountCap _supplyCap = AmountCap.wrap(supplyCap);
        // Max total assets is a sum of max pool size and max total debt, both Assets type
        if (supplyCap > 0 && _supplyCap.toUint() > 2 * MAX_SANE_AMOUNT) revert E_BadSupplyCap();

        AmountCap _borrowCap = AmountCap.wrap(borrowCap);
        if (borrowCap > 0 && _borrowCap.toUint() > MAX_SANE_AMOUNT) revert E_BadBorrowCap();

        marketStorage.supplyCap = _supplyCap;
        marketStorage.borrowCap = _borrowCap;

        emit GovSetCaps(supplyCap, borrowCap);
    }

    /// @inheritdoc IGovernance
    function setInterestFee(uint16 newInterestFee) external virtual nonReentrant governorOnly {
        ConfigAmount newInterestFeeConfig = newInterestFee.toConfigAmount();

        // Interest fees between 1 and 50% are always allowed, otherwise ask protocolConfig
        if (newInterestFee < CONFIGAMOUNT_1_PERCENT || newInterestFee > CONFIGAMOUNT_50_PERCENT) {
            if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert E_BadFee();
        }

        marketStorage.interestFee = newInterestFeeConfig;

        emit GovSetInterestFee(newInterestFee);
    }

    /// @inheritdoc IGovernance
    function setDebtSocialization(bool newValue) external virtual nonReentrant governorOnly {
        marketStorage.debtSocialization = newValue;

        emit GovSetDebtSocialization(newValue);
    }
}

contract Governance is GovernanceModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

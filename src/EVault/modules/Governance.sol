// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {LTVUtils} from "../shared/LTVUtils.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base, BalanceUtils, BorrowUtils, LTVUtils {
    using TypesLib for uint16;

    // Protocol guarantees
    uint16 constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;
    uint16 constant GUARANTEED_INTEREST_FEE_MIN = 0.1e4;
    uint16 constant GUARANTEED_INTEREST_FEE_MAX = 1e4;

    event GovSetName(string newName);
    event GovSetSymbol(string newSymbol);
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetPauseGuardian(address newPauseGuardian);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetLTV(
        address indexed collateral, uint48 targetTimestamp, uint16 targetLTV, uint32 rampDuration, uint16 originalLTV
    );
    event GovSetIRM(address interestRateModel);
    event GovSetDisabledOps(uint32 newDisabledOps);
    event GovSetConfigFlags(uint32 newConfigFlags);
    event GovSetLockedOps(uint32 newLockedOps);
    event GovSetCaps(uint16 newSupplyCap, uint16 newBorrowCap);
    event GovSetInterestFee(uint16 newFee);

    modifier governorOnly() {
        if (msg.sender != marketStorage.governorAdmin) revert E_Unauthorized();
        _;
    }

    modifier governorOrPauseGuardianOnly() {
        if (msg.sender != marketStorage.governorAdmin && msg.sender != marketStorage.pauseGuardian) {
            revert E_Unauthorized();
        }
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() public view virtual reentrantOK returns (address) {
        return marketStorage.governorAdmin;
    }

    /// @inheritdoc IGovernance
    function pauseGuardian() public view virtual reentrantOK returns (address) {
        return marketStorage.pauseGuardian;
    }

    /// @inheritdoc IGovernance
    function interestFee() public view virtual reentrantOK returns (uint16) {
        return marketStorage.interestFee.toUint16();
    }

    /// @inheritdoc IGovernance
    function protocolFeeShare() public view virtual reentrantOK returns (uint256) {
        (, uint256 protocolShare) = protocolConfig.protocolFeeConfig(address(this));
        return protocolShare;
    }

    /// @inheritdoc IGovernance
    function protocolFeeReceiver() public view virtual reentrantOK returns (address) {
        (address protocolReceiver,) = protocolConfig.protocolFeeConfig(address(this));
        return protocolReceiver;
    }

    /// @inheritdoc IGovernance
    function protocolConfigAddress() public view virtual reentrantOK returns (address) {
        return address(protocolConfig);
    }

    /// @inheritdoc IGovernance
    function borrowingLTV(address collateral) public view virtual reentrantOK returns (uint16) {
        return getLTV(collateral, LTVType.BORROWING).toUint16();
    }

    /// @inheritdoc IGovernance
    function liquidationLTV(address collateral) public view virtual reentrantOK returns (uint16) {
        return getLTV(collateral, LTVType.LIQUIDATION).toUint16();
    }

    /// @inheritdoc IGovernance
    function LTVFull(address collateral) public view virtual reentrantOK returns (uint48, uint16, uint32, uint16) {
        LTVConfig memory ltv = marketStorage.ltvLookup[collateral];
        return (ltv.targetTimestamp, ltv.targetLTV.toUint16(), ltv.rampDuration, ltv.originalLTV.toUint16());
    }

    /// @inheritdoc IGovernance
    function LTVList() public view virtual reentrantOK returns (address[] memory) {
        return marketStorage.ltvList;
    }

    /// @inheritdoc IGovernance
    function interestRateModel() public view virtual reentrantOK returns (address) {
        return marketStorage.interestRateModel;
    }

    /// @inheritdoc IGovernance
    function disabledOps() public view virtual reentrantOK returns (uint32) {
        return (marketStorage.disabledOps.toUint32());
    }

    /// @inheritdoc IGovernance
    function configFlags() public view virtual reentrantOK returns (uint32) {
        return (marketStorage.configFlags.toUint32());
    }

    /// @inheritdoc IGovernance
    function lockedOps() public view virtual reentrantOK returns (uint32) {
        return (marketStorage.lockedOps.toUint32());
    }

    /// @inheritdoc IGovernance
    function caps() public view virtual reentrantOK returns (uint16, uint16) {
        return (marketStorage.supplyCap.toRawUint16(), marketStorage.borrowCap.toRawUint16());
    }

    /// @inheritdoc IGovernance
    function feeReceiver() public view virtual reentrantOK returns (address) {
        return marketStorage.feeReceiver;
    }

    /// @inheritdoc IGovernance
    function EVC() public view virtual reentrantOK returns (address) {
        return address(evc);
    }

    /// @inheritdoc IGovernance
    function permit2Address() public view virtual reentrantOK returns (address) {
        return permit2;
    }

    /// @inheritdoc IGovernance
    function unitOfAccount() public view virtual reentrantOK returns (address) {
        (,, address _unitOfAccount) = ProxyUtils.metadata();
        return _unitOfAccount;
    }

    /// @inheritdoc IGovernance
    function oracle() public view virtual reentrantOK returns (address) {
        (, IPriceOracle _oracle,) = ProxyUtils.metadata();
        return address(_oracle);
    }

    /// @inheritdoc IGovernance
    function convertFees() public virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, CHECKACCOUNT_NONE);

        if (marketCache.accumulatedFees.isZero()) return;

        (address protocolReceiver, uint16 protocolFee) = protocolConfig.protocolFeeConfig(address(this));
        address governorReceiver = marketStorage.feeReceiver;

        if (governorReceiver == address(0)) {
            protocolFee = 1e4; // governor forfeits fees
        } else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) {
            protocolFee = MAX_PROTOCOL_FEE_SHARE;
        }

        Shares governorShares = marketCache.accumulatedFees.mulDiv(1e4 - protocolFee, 1e4);
        Shares protocolShares = marketCache.accumulatedFees - governorShares;

        marketStorage.accumulatedFees = marketCache.accumulatedFees = Shares.wrap(0);

        // Decrease totalShares because increaseBalance will increase it by that total amount
        marketStorage.totalShares = marketCache.totalShares = marketCache.totalShares - marketCache.accumulatedFees;

        // For the Deposit events in increaseBalance the assets amount is zero - the shares are covered with the accrued interest
        if (!governorShares.isZero()) {
            increaseBalance(marketCache, governorReceiver, address(0), governorShares, Assets.wrap(0));
        }

        if (!protocolShares.isZero()) {
            increaseBalance(marketCache, protocolReceiver, address(0), protocolShares, Assets.wrap(0));
        }

        emit ConvertFees(account, protocolReceiver, governorReceiver, protocolShares.toUint(), governorShares.toUint());
    }

    /// @inheritdoc IGovernance
    function setName(string calldata newName) public virtual nonReentrant governorOnly {
        marketStorage.name = newName;
        emit GovSetName(newName);
    }

    /// @inheritdoc IGovernance
    function setSymbol(string calldata newSymbol) public virtual nonReentrant governorOnly {
        marketStorage.symbol = newSymbol;
        emit GovSetSymbol(newSymbol);
    }

    /// @inheritdoc IGovernance
    function setGovernorAdmin(address newGovernorAdmin) public virtual nonReentrant governorOnly {
        marketStorage.governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @inheritdoc IGovernance
    function setPauseGuardian(address newPauseGuardian) public virtual nonReentrant governorOnly {
        marketStorage.pauseGuardian = newPauseGuardian;
        emit GovSetPauseGuardian(newPauseGuardian);
    }

    /// @inheritdoc IGovernance
    function setFeeReceiver(address newFeeReceiver) public virtual nonReentrant governorOnly {
        marketStorage.feeReceiver = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    /// @inheritdoc IGovernance
    function setLTV(address collateral, uint16 ltv, uint32 rampDuration) public virtual nonReentrant governorOnly {
        // self-collateralization is not allowed
        if (collateral == address(this)) revert E_InvalidLTVAsset();

        ConfigAmount newLTVAmount = ltv.toConfigAmount();
        LTVConfig memory origLTV = marketStorage.ltvLookup[collateral];

        // If new LTV is higher than the previous, or the same, it should take effect immediately
        if (!(newLTVAmount < origLTV.getLTV(LTVType.LIQUIDATION)) && rampDuration > 0) revert E_LTVRamp();

        LTVConfig memory newLTV = origLTV.setLTV(newLTVAmount, rampDuration);

        marketStorage.ltvLookup[collateral] = newLTV;

        if (!origLTV.initialized) marketStorage.ltvList.push(collateral);

        emit GovSetLTV(
            collateral,
            newLTV.targetTimestamp,
            newLTV.targetLTV.toUint16(),
            newLTV.rampDuration,
            newLTV.originalLTV.toUint16()
        );
    }

    /// @inheritdoc IGovernance
    function clearLTV(address collateral) public virtual nonReentrant governorOnly {
        uint16 originalLTV = getLTV(collateral, LTVType.LIQUIDATION).toUint16();
        marketStorage.ltvLookup[collateral].clear();

        emit GovSetLTV(collateral, 0, 0, 0, originalLTV);
    }

    /// @inheritdoc IGovernance
    function setIRM(address newModel) public virtual nonReentrant governorOnly {
        MarketCache memory marketCache = updateMarket();

        marketStorage.interestRateModel = newModel;
        marketStorage.interestRate = 0;

        uint256 newInterestRate = computeInterestRate(marketCache);

        logMarketStatus(marketCache, newInterestRate);

        emit GovSetIRM(newModel);
    }

    /// @inheritdoc IGovernance
    function setDisabledOps(uint32 newDisabledOps) public virtual nonReentrant governorOrPauseGuardianOnly {
        // Overwrite bits of locked ops with their currently set values
        newDisabledOps = (newDisabledOps & ~marketStorage.lockedOps.toUint32())
            | (marketStorage.disabledOps.toUint32() & marketStorage.lockedOps.toUint32());

        // market is updated because:
        // if disabling interest accrual - the pending interest should be accrued
        // if re-enabling interest - last updated timestamp needs to be reset to skip the disabled period
        MarketCache memory marketCache = updateMarket();
        logMarketStatus(marketCache, marketStorage.interestRate);

        marketStorage.disabledOps = Flags.wrap(newDisabledOps);
        emit GovSetDisabledOps(newDisabledOps);
    }

    /// @inheritdoc IGovernance
    function setLockedOps(uint32 newLockedOps) public virtual nonReentrant governorOnly {
        marketStorage.lockedOps = Flags.wrap(newLockedOps);
        emit GovSetLockedOps(newLockedOps);
    }

    /// @inheritdoc IGovernance
    function setConfigFlags(uint32 newConfigFlags) public virtual nonReentrant governorOnly {
        marketStorage.configFlags = Flags.wrap(newConfigFlags);
        emit GovSetConfigFlags(newConfigFlags);
    }

    /// @inheritdoc IGovernance
    function setCaps(uint16 supplyCap, uint16 borrowCap) public virtual nonReentrant governorOnly {
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
    function setInterestFee(uint16 newInterestFee) public virtual nonReentrant governorOnly {
        // Update market to apply the current interest fee to the pending interest
        MarketCache memory marketCache = updateMarket();
        logMarketStatus(marketCache, marketStorage.interestRate);

        // Interest fees in guaranteed range are always allowed, otherwise ask protocolConfig
        if (newInterestFee < GUARANTEED_INTEREST_FEE_MIN || newInterestFee > GUARANTEED_INTEREST_FEE_MAX) {
            if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert E_BadFee();
        }

        marketStorage.interestFee = newInterestFee.toConfigAmount();

        emit GovSetInterestFee(newInterestFee);
    }
}

contract Governance is GovernanceModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

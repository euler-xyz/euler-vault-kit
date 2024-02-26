// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base, BalanceUtils {
    modifier governorOnly() {
        if (msg.sender != marketStorage.governorAdmin) revert RM_Unauthorized();
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() external virtual view returns (address) {
        return marketStorage.governorAdmin;
    }

    /// @inheritdoc IGovernance
    function interestFee() external view virtual reentrantOK returns (uint16) {
        return marketStorage.interestFee;
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
    function LTV(address collateral) external virtual view returns (uint16) {
        return ltvLookup[collateral].getLTV();
    }

    /// @inheritdoc IGovernance
    function LTVList() external virtual view returns (address[] memory) {
        return ltvList;
    }

    /// @inheritdoc IGovernance
    function interestRateModel() external virtual view returns (address) {
        return marketStorage.interestRateModel;
    }

    /// @inheritdoc IGovernance
    function marketPolicy() external virtual view returns (uint32 disabledOps, uint16 supplyCap, uint16 borrowCap) {
        return (marketStorage.disabledOps.toUint32(), marketStorage.supplyCap.toRawUint16(), marketStorage.borrowCap.toRawUint16());
    }

    /// @inheritdoc IGovernance
    function feeReceiver() external virtual view returns (address) {
        return marketStorage.feeReceiver;
    }

    /// @inheritdoc IGovernance
    function debtSocialization() external virtual view returns (bool) {
        return marketStorage.debtSocialization;
    }

    /// @inheritdoc IGovernance
    function unitOfAccount() external virtual view returns (address) {
        (,, address _unitOfAccount) = ProxyUtils.metadata();
        return _unitOfAccount;
    }

    /// @inheritdoc IGovernance
    function oracle() external virtual view returns (address) {
        (, IPriceOracle _oracle,) = ProxyUtils.metadata();
        return address(_oracle);
    }

     /// @inheritdoc IGovernance
    function convertFees() external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, ACCOUNTCHECK_NONE);

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

        increaseBalance(
            marketCache, governorReceiver, address(0), governorShares, governorShares.toAssetsDown(marketCache)
        ); // TODO confirm address(0)
        increaseBalance(
            marketCache, protocolReceiver, address(0), protocolShares, protocolShares.toAssetsDown(marketCache)
        );

        emit ConvertFees(
            account,
            protocolReceiver,
            governorReceiver,
            protocolShares.toAssetsDown(marketCache).toUint(),
            governorShares.toAssetsDown(marketCache).toUint()
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
    function setFeeReceiver(address newFeeReceiver) external virtual nonReentrant governorOnly {
        marketStorage.feeReceiver = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    /// @inheritdoc IGovernance
    function setLTV(address collateral, uint16 ltv, uint24 rampDuration) external virtual nonReentrant governorOnly {
        MarketCache memory marketCache = loadMarket();
        if (collateral == address(marketCache.asset)) revert RM_InvalidLTVAsset();

        LTVConfig memory origLTV = ltvLookup[collateral].setLTV(ltv, rampDuration);
        LTVConfig memory newLTV = origLTV.setLTV(ltv, rampDuration);

        ltvLookup[collateral] = newLTV;

        if (!origLTV.initialised()) ltvList.push(collateral);

        emit GovSetLTV(collateral, newLTV);
    }

    /// @inheritdoc IGovernance
    function setIRM(address newModel, bytes calldata resetParams) external virtual nonReentrant governorOnly {
        // TODO IIRM reset ?

        marketStorage.interestRateModel = newModel;

        emit GovSetIRM(newModel, resetParams);
    }

    /// @inheritdoc IGovernance
    function setMarketPolicy(uint32 disabledOps, uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        AmountCap _supplyCap = AmountCap.wrap(supplyCap);
        // Max total assets is a sum of max pool size and max total debt, both Assets type
        if (supplyCap > 0 && _supplyCap.toUint() > 2 * MAX_SANE_AMOUNT) revert E_BadSupplyCap();

        AmountCap _borrowCap = AmountCap.wrap(borrowCap);
        if (borrowCap > 0 && _borrowCap.toUint() > MAX_SANE_AMOUNT) revert E_BadBorrowCap();

        marketStorage.disabledOps = DisabledOps.wrap(disabledOps);
        marketStorage.supplyCap = _supplyCap;
        marketStorage.borrowCap = _borrowCap;

        emit GovSetMarketPolicy(disabledOps, supplyCap, borrowCap);
    }

    /// @inheritdoc IGovernance
    function setInterestFee(uint16 newInterestFee) external virtual nonReentrant governorOnly {
        if (newInterestFee > CONFIG_SCALE) revert RM_BadFee();

        if (newInterestFee == marketStorage.interestFee) return;

        if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert RM_BadFee();

        marketStorage.interestFee = newInterestFee;

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

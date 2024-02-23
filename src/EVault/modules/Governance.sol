// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base {
    modifier governorOnly() {
        if (msg.sender != marketStorage.governorAdmin) revert RM_Unauthorized();
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() external virtual view returns (address) {
        return marketStorage.governorAdmin;
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
        return (marketStorage.disabledOps.toUint32(), marketStorage.supplyCap.toUint16(), marketStorage.borrowCap.toUint16());
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
        return marketStorage.unitOfAccount;
    }

    /// @inheritdoc IGovernance
    function oracle() external virtual view returns (address) {
        return marketStorage.oracle;
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
    function setOracle(address newOracle) external virtual nonReentrant governorOnly {
        marketStorage.oracle = newOracle;

        emit GovSetOracle(newOracle);
    }

    /// @inheritdoc IGovernance
    function setMarketPolicy(uint32 disabledOps, uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        marketStorage.disabledOps = DisabledOps.wrap(disabledOps);
        marketStorage.supplyCap = AmountCap.wrap(supplyCap).validate();
        marketStorage.borrowCap = AmountCap.wrap(borrowCap).validate();

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

    /// @inheritdoc IGovernance
    function setUnitOfAccount(address newUnitOfAccount) external virtual nonReentrant governorOnly {
        marketStorage.unitOfAccount = newUnitOfAccount;

        emit GovSetUnitOfAccount(newUnitOfAccount);
    }
}

contract Governance is GovernanceModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

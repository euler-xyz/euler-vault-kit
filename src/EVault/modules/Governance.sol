// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base {
    modifier governorOnly() {
        if (msg.sender != governorAdminAddress) revert RM_Unauthorized();
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() external virtual view returns (address) {
        return governorAdminAddress;
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
        return marketConfig.interestRateModel;
    }

    /// @inheritdoc IGovernance
    function marketPolicy() external virtual view returns (uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) {
        return (marketConfig.pauseBitmask, marketConfig.supplyCap.toUint16(), marketConfig.borrowCap.toUint16());
    }

    /// @inheritdoc IGovernance
    function feeReceiver() external virtual view returns (address) {
        return feeReceiverAddress;
    }

    /// @inheritdoc IGovernance
    function debtSocialization() external virtual view returns (bool) {
        return marketConfig.debtSocialization;
    }

    /// @inheritdoc IGovernance
    function unitOfAccount() external virtual view returns (address) {
        return marketConfig.unitOfAccount;
    }

    /// @inheritdoc IGovernance
    function oracle() external virtual view returns (address) {
        return marketConfig.oracle;
    }

    /// @inheritdoc IGovernance
    function setName(string calldata newName) external virtual nonReentrant governorOnly {
        marketConfig.name = newName;
        emit GovSetName(newName);
    }

    /// @inheritdoc IGovernance
    function setSymbol(string calldata newSymbol) external virtual nonReentrant governorOnly {
        marketConfig.symbol = newSymbol;
        emit GovSetSymbol(newSymbol);
    }

    /// @inheritdoc IGovernance
    function setGovernorAdmin(address newGovernorAdmin) external virtual nonReentrant governorOnly {
        governorAdminAddress = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @inheritdoc IGovernance
    function setFeeReceiver(address newFeeReceiver) external virtual nonReentrant governorOnly {
        feeReceiverAddress = newFeeReceiver;
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

        marketConfig.interestRateModel = newModel;

        emit GovSetIRM(newModel, resetParams);
    }

    /// @inheritdoc IGovernance
    function setOracle(address newOracle) external virtual nonReentrant governorOnly {
        marketConfig.oracle = newOracle;

        emit GovSetOracle(newOracle);
    }

    /// @inheritdoc IGovernance
    function setMarketPolicy(uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        marketConfig.pauseBitmask = pauseBitmask;
        marketConfig.supplyCap = AmountCap.wrap(supplyCap).validate();
        marketConfig.borrowCap = AmountCap.wrap(borrowCap).validate();

        emit GovSetMarketPolicy(pauseBitmask, supplyCap, borrowCap);
    }

    /// @inheritdoc IGovernance
    function setInterestFee(uint16 newInterestFee) external virtual nonReentrant governorOnly {
        if (newInterestFee > CONFIG_SCALE) revert RM_BadFee();

        if (newInterestFee == marketConfig.interestFee) return;

        if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert RM_BadFee();

        marketConfig.interestFee = newInterestFee;

        emit GovSetInterestFee(newInterestFee);
    }

    /// @inheritdoc IGovernance
    function setDebtSocialization(bool newValue) external virtual nonReentrant governorOnly {
        marketConfig.debtSocialization = newValue;

        emit GovSetDebtSocialization(newValue);
    }

    /// @inheritdoc IGovernance
    function setUnitOfAccount(address newUnitOfAccount) external virtual nonReentrant governorOnly {
        marketConfig.unitOfAccount = newUnitOfAccount;

        emit GovSetUnitOfAccount(newUnitOfAccount);
    }
}

contract Governance is GovernanceModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

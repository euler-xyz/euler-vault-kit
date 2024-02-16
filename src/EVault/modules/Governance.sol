// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IGovernance} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

import "../shared/types/Types.sol";

abstract contract GovernanceModule is IGovernance, Base {
    modifier governorOnly() {
        if (msg.sender != governorAdmin) revert RM_Unauthorized();
        _;
    }

    event GovSetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetLTV(address indexed collateral, LTVConfig newLTV);
    event GovSetIRM(address interestRateModel, bytes resetParams);
    event GovSetOracle(address oracle);
    event GovSetMarketPolicy(uint32 newPauseBitmask, uint64 newSupplyCap, uint64 newBorrowCap);
    event GovSetInterestFee(uint16 newFee);
    event GovSetDebtSocialization(bool debtSocialization);
    event GovSetUnitOfAccount(address newUnitOfAccount);

    function setGovernorAdmin(address newGovernorAdmin) external virtual nonReentrant governorOnly {
        governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    function setFeeReceiver(address newFeeReceiver) external virtual nonReentrant governorOnly {
        feeReceiverAddress = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    function setLTV(address collateral, uint16 ltv, uint24 rampDuration) external virtual nonReentrant governorOnly {
        MarketCache memory marketCache = loadMarket();
        if (collateral == address(marketCache.asset)) revert RM_InvalidLTVAsset();

        LTVConfig memory origLTV = ltvLookup[collateral].setLTV(ltv, rampDuration);
        LTVConfig memory newLTV = origLTV.setLTV(ltv, rampDuration);

        ltvLookup[collateral] = newLTV;

        if (!origLTV.initialised()) ltvList.push(collateral);

        emit GovSetLTV(collateral, newLTV);
    }

    // After setting a new IRM, touch() should be called on a market
    function setIRM(address newModel, bytes calldata resetParams) external virtual nonReentrant governorOnly {
        // TODO IIRM reset ?

        marketConfig.interestRateModel = newModel;

        emit GovSetIRM(newModel, resetParams);
    }

    function setOracle(address newOracle) external virtual nonReentrant governorOnly {
        marketConfig.oracle = newOracle;

        emit GovSetOracle(newOracle);
    }

    function setMarketPolicy(uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        marketConfig.pauseBitmask = pauseBitmask;
        marketConfig.supplyCap = AmountCap.wrap(supplyCap).validate();
        marketConfig.borrowCap = AmountCap.wrap(borrowCap).validate();

        emit GovSetMarketPolicy(pauseBitmask, supplyCap, borrowCap);
    }

    function setInterestFee(uint16 newInterestFee) external virtual nonReentrant governorOnly {
        if (newInterestFee > CONFIG_SCALE) revert RM_BadFee();

        if (newInterestFee == marketConfig.interestFee) return;

        if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert RM_BadFee();

        marketStorage.interestFee = newInterestFee;

        emit GovSetInterestFee(newInterestFee);
    }

    function setDebtSocialization(bool newValue) external virtual nonReentrant governorOnly {
        marketConfig.debtSocialization = newValue;

        emit GovSetDebtSocialization(newValue);
    }

    function setUnitOfAccount(address newUnitOfAccount) external virtual nonReentrant governorOnly {
        marketConfig.unitOfAccount = newUnitOfAccount;

        emit GovSetUnitOfAccount(newUnitOfAccount);
    }

    // Getters

    function getGovernorAdmin() external virtual view returns (address) {
        return governorAdmin;
    }

    /// @notice Retrieves LTV config for a collateral
    /// @param collateral Collateral asset
    /// @return LTV config set for the pair
    function getLTV(address collateral) external virtual view returns (uint16) {
        return ltvLookup[collateral].getLTV();
    }

    /// @notice Retrieves a list of collaterals with configured LTVs
    /// @return List of asset collaterals
    /// @dev The list can have duplicates. Returned assets could have the ltv disabled
    function getLTVList() external virtual view returns (address[] memory) {
        return ltvList;
    }

    /// @notice Looks up an asset's currently configured interest rate model
    /// @return Address of the interest rate contract
    function interestRateModel() external virtual view returns (address) {
        return marketConfig.interestRateModel;
    }

    function getMarketPolicy() external virtual view returns (uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) {
        return (marketConfig.pauseBitmask, marketConfig.supplyCap.toUint16(), marketConfig.borrowCap.toUint16());
    }

    function feeReceiver() external virtual view returns (address) {
        return feeReceiverAddress;
    }

    function debtSocialization() external virtual view returns (bool) {
        return marketConfig.debtSocialization;
    }

    function unitOfAccount() external virtual view returns (address) {
        return marketConfig.unitOfAccount;
    }

    function oracle() external virtual view returns (address) {
        return marketConfig.oracle;
    }
}

contract Governance is GovernanceModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

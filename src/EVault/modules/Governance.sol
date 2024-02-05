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

    event SetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetMarketConfig(uint256 collateralFactor, uint256 borrowFactor);
    event GovSetLTV(address indexed collateral, LTVConfig newLTV);
    event GovSetIRM(address interestRateModel, bytes resetParams);
    event GovSetMarketPolicy(uint32 newPauseBitmask, uint64 newSupplyCap, uint64 newBorrowCap);
    event GovSetInterestFee(uint16 newFee);
    event GovSetUnitOfAccount(address newUnitOfAccount);

    function setDefaultInterestRateModel(address newModel) external virtual nonReentrant governorOnly {
        if (newModel == address(0)) revert RM_InvalidIRM();

        marketConfig.interestRateModel = newModel;
    }

    function setGovernorAdmin(address newGovernorAdmin) external virtual nonReentrant governorOnly {
        governorAdmin = newGovernorAdmin;
        emit SetGovernorAdmin(newGovernorAdmin);
    }

    function setFeeReceiver(address newFeeReceiver) external virtual nonReentrant governorOnly {
        feeReceiverAddress = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    function setLTV(address collateral, LTVConfig calldata newLTV) external virtual nonReentrant governorOnly {
        MarketCache memory marketCache = loadMarket();
        if (collateral == address(marketCache.asset)) revert RM_InvalidLTVAsset();

        ltvLookup[collateral] = newLTV;

        updateLTVArray(ltvList, collateral, newLTV);

        emit GovSetLTV(collateral, newLTV);
    }

    // After setting a new IRM, touch() should be called on a market
    function setIRM(address newModel, bytes calldata resetParams) external virtual nonReentrant governorOnly {
        // IIRM reset ?

        marketConfig.interestRateModel = newModel;

        emit GovSetIRM(newModel, resetParams);
    }

    function setMarketPolicy(uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) external virtual nonReentrant governorOnly {
        marketConfig.pauseBitmask = pauseBitmask;
        marketConfig.supplyCap = AmountCap.wrap(supplyCap).validate();
        marketConfig.borrowCap = AmountCap.wrap(borrowCap).validate();

        emit GovSetMarketPolicy(pauseBitmask, supplyCap, borrowCap);
    }

    // NOTE separate setters for fees not to emit extra events on the core if only liquidation is changed.
    function setInterestFee(uint16 newFee) external virtual nonReentrant governorOnly {
        if (newFee > CONFIG_SCALE && newFee != type(uint16).max) revert RM_BadFee();
        // TODO check min interest fee from the vault

        marketConfig.interestFee = newFee;

        emit GovSetInterestFee(newFee);
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
    function getLTV(address collateral) external virtual view returns (LTVConfig memory) {
        return ltvLookup[collateral];
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

    function getDefaultInterestRateModel() external virtual view returns (address) {
        return defaultInterestRateModel;
    }

    function getMarketPolicy() external virtual view returns (uint32 pauseBitmask, uint16 supplyCap, uint16 borrowCap) {
        return (marketConfig.pauseBitmask, marketConfig.supplyCap.toUint16(), marketConfig.borrowCap.toUint16());
    }

    function feeReceiver() external virtual view returns (address) {
        return feeReceiverAddress;
    }

    // Internal

    function updateLTVArray(address[] storage arr, address asset, LTVConfig calldata newLTV) private {
        uint256 length = arr.length;
        if (newLTV.enabled) {
            for (uint256 i = 0; i < length;) {
                if (arr[i] == asset) return;
                unchecked {
                    ++i;
                }
            }
            arr.push(asset);
        } else {
            for (uint256 i = 0; i < length;) {
                if (arr[i] == asset) {
                    arr[i] = arr[length - 1];
                    arr.pop();
                    return;
                }
                unchecked {
                    ++i;
                }
            }
        }
    }
}

contract Governance is GovernanceModule {
    constructor(address evc, address protocolAdmin, address balanceTracker) Base(evc, protocolAdmin, balanceTracker) {}
}

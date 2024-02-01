// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./RiskManagerCoreBase.sol";
import "../../interestRateModels/IIRM.sol";

abstract contract RiskManagerCoreGovernance is RiskManagerCoreBase {
    constructor(address _governorAdmin) {
        governorAdmin = _governorAdmin;
        feeReceiverAddress = _governorAdmin;
    }

    modifier governorOnly() {
        if (msg.sender != governorAdmin) revert RM_Unauthorized();
        _;
    }

    event SetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetMarketConfig(address indexed market, uint256 collateralFactor, uint256 borrowFactor);
    event GovSetOverride(address indexed liability, address indexed collateral, OverrideConfig newOverride);
    event GovSetIRM(address indexed market, address interestRateModel, bytes resetParams);
    event GovSetMarketPolicy(address indexed market, uint32 newPauseBitmask, uint64 newSupplyCap, uint64 newBorrowCap);
    event GovSetInterestFee(address indexed market, uint16 newFee);

    function setDefaultInterestRateModel(address market, address newModel) external governorOnly {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();
        if (newModel == address(0)) revert RM_InvalidIRM();

        config.interestRateModel = newModel;
    }

    function setGovernorAdmin(address newGovernorAdmin) external governorOnly {
        if (newGovernorAdmin == address(0)) revert RM_BadGovernorAddress();
        governorAdmin = newGovernorAdmin;
        emit SetGovernorAdmin(newGovernorAdmin);
    }

    function setFeeReceiver(address newFeeReceiver) external governorOnly {
        if (newFeeReceiver == address(0)) revert RM_BadFeeReceiverAddress();
        feeReceiverAddress = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    function setMarketConfig(address market, uint16 collateralFactor, uint16 borrowFactor) external governorOnly {
        MarketConfig storage config = markets[market];
        if (isExternalMarket(config)) revert RM_ExternalMarket();
        config.collateralFactor = collateralFactor;
        config.borrowFactor = borrowFactor;

        emit GovSetMarketConfig(market, collateralFactor, borrowFactor);
    }

    function setOverride(address liability, address collateral, OverrideConfig calldata newOverride)
        external
        governorOnly
    {
        if (!markets[liability].activated || !markets[collateral].activated) {
            revert RM_MarketNotActivated();
        }
        if (isExternalMarket(markets[liability])) revert RM_ExternalMarket();

        overrideLookup[liability][collateral] = newOverride;

        updateOverridesArray(overrideCollaterals[liability], collateral, newOverride);
        updateOverridesArray(overrideLiabilities[collateral], liability, newOverride);

        emit GovSetOverride(liability, collateral, newOverride);
    }

    // After setting a new IRM, touch() should be called on a market
    function setIRM(address market, address newModel, bytes calldata resetParams) external governorOnly {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();
        if (isExternalMarket(config)) revert RM_ExternalMarket();

        (bool success, bytes memory data) =
            config.interestRateModel.call(abi.encodeCall(IIRM.reset, (market, resetParams)));
        if (!success) {
            if (data.length == 0) revert RM_InvalidIRM();
            revertBytes(data);
        }

        config.interestRateModel = newModel;

        emit GovSetIRM(market, newModel, resetParams);
    }

    function setMarketPolicy(address market, uint32 pauseBitmask, uint64 supplyCap, uint64 borrowCap)
        external
        governorOnly
    {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();
        if (isExternalMarket(config)) revert RM_ExternalMarket();

        config.pauseBitmask = pauseBitmask;
        config.supplyCap = supplyCap;
        config.borrowCap = borrowCap;

        emit GovSetMarketPolicy(market, pauseBitmask, supplyCap, borrowCap);
    }

    // NOTE separate setters for fees not to emit extra events on the core if only liquidation is changed.
    function setInterestFee(address market, uint16 newFee) external governorOnly {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();
        if (isExternalMarket(config)) revert RM_ExternalMarket();
        if (newFee > CONFIG_SCALE && newFee != type(uint16).max) revert RM_BadFee();
        // TODO check min interest fee from the vault

        config.interestFee = newFee;

        emit GovSetInterestFee(market, newFee);
    }

    // getters

    function getGovernorAdmin() external view returns (address) {
        return governorAdmin;
    }

    /// @notice Looks up the Euler-related configuration for a market, and returns it unresolved (with default-value placeholders)
    /// @param market Market address
    /// @return collateralFactor Default collateral factor of the market
    /// @return borrowFactor Default borrow factor of the market
    function getMarketConfigUnresolved(address market)
        external
        view
        returns (uint256 collateralFactor, uint256 borrowFactor)
    {
        MarketConfig memory config = markets[market];
        collateralFactor = config.collateralFactor;
        borrowFactor = config.borrowFactor;
    }

    /// @notice Looks up the Euler-related configuration for a market, and resolves all default-value placeholders to their currently configured values.
    /// @param market Market address
    /// @return collateralFactor Default collateral factor of the market
    /// @return borrowFactor Default borrow factor of the market
    function getMarketConfig(address market) external view returns (uint256 collateralFactor, uint256 borrowFactor) {
        MarketConfig memory config = resolveMarketConfig(market);
        collateralFactor = config.collateralFactor;
        borrowFactor = config.borrowFactor;
    }

    /// @notice Retrieves collateral factor override for asset pair
    /// @param liability Borrowed asset
    /// @param collateral Collateral asset
    /// @return Override config set for the pair
    function getOverride(address liability, address collateral) external view returns (OverrideConfig memory) {
        return overrideLookup[liability][collateral];
    }

    /// @notice Retrieves a list of collaterals configured through override for the liability asset
    /// @param liability Borrowed asset
    /// @return List of asset collaterals with override configured
    /// @dev The list can have duplicates. Returned assets could have the override disabled
    function getOverrideCollaterals(address liability) external view returns (address[] memory) {
        return overrideCollaterals[liability];
    }

    /// @notice Retrieves a list of liabilities configured through override for the collateral asset
    /// @param collateral Collateral asset
    /// @return List of asset liabilities with override configured
    /// @dev The list can have duplicates. Returned assets could have the override disabled
    function getOverrideLiabilities(address collateral) external view returns (address[] memory) {
        return overrideLiabilities[collateral];
    }

    /// @notice Looks up an asset's currently configured interest rate model
    /// @param market Market address
    /// @return Address of the interest rate contract
    function interestRateModel(address market) external view returns (address) {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();

        return config.interestRateModel;
    }

    function getDefaultInterestRateModel() external view returns (address) {
        return defaultInterestRateModel;
    }

    function getMarketPolicy(address market)
        external
        view
        returns (uint32 pauseBitmask, uint64 supplyCap, uint64 borrowCap)
    {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();

        return (config.pauseBitmask, config.supplyCap, config.borrowCap);
    }

    function feeReceiver() external view returns (address) {
        return feeReceiverAddress;
    }
    // Internal

    function resolveMarketConfig(address market) internal view override returns (MarketConfig memory) {
        // TODO resolveCollateralConfig / resolveControllerConfig?
        // TODO optimize 3 storage reads
        // TODO revisit all of config handling
        MarketConfig memory config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();

        if (config.borrowFactor == type(uint16).max) config.borrowFactor = DEFAULT_BORROW_FACTOR;
        if (config.interestFee == type(uint16).max) config.interestFee = DEFAULT_INTEREST_FEE;

        return config;
    }

    function resolveCollateralFactor(
        address collateral,
        address liability,
        MarketConfig memory collateralConfig,
        MarketConfig memory liabilityConfig
    ) internal view returns (uint256) {
        OverrideConfig memory overrideConfig = overrideLookup[liability][collateral];

        if (overrideConfig.enabled) return overrideConfig.collateralFactor;

        // If override is not available, use default asset collateral and borrow factors, unless collateral and liability are the same.
        return collateral == liability
            ? 0
            : uint256(collateralConfig.collateralFactor) * liabilityConfig.borrowFactor / CONFIG_SCALE;
    }

    function updateOverridesArray(address[] storage arr, address asset, OverrideConfig calldata newOverride) private {
        uint256 length = arr.length;
        if (newOverride.enabled) {
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

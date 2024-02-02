// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../IRiskManager.sol";
import "../../Interfaces.sol";

abstract contract RiskManagerCoreBase is IRiskManager {
    address immutable factory;
    address immutable evc;
    address immutable oracle;
    address immutable referenceAsset;

    constructor(address factory_, address evc_, address oracle_, address referenceAsset_) {
        factory = factory_;
        evc = evc_;
        oracle = oracle_;
        referenceAsset = referenceAsset_;
    }

    // ERRORS

    error RM_Unauthorized();
    error RM_AccountLiquidity();
    error RM_MarketActivated();
    error RM_UnderlyingActivated();
    error RM_InvalidUnderlying();

    error RM_NoLiability();
    error RM_UnsupportedLiability();
    error RM_IncorrectRiskManager();
    error RM_MarketNotActivated();
    error RM_EmptyError();
    error RM_InvalidIRM();
    error RM_BadGovernorAddress();
    error RM_BadFeeReceiverAddress();
    error RM_ExcessiveRepay();
    error RM_ExcessiveYield();
    error RM_TooManyDecimals();
    error RM_MarketAlreadyActivated();
    error RM_ExternalMarket();
    error RM_InsufficientBalance();
    error RM_BadFee();
    error RM_ExcessiveRepayAmount();
    error RM_TransientState();
    error RM_OperationPaused();
    error RM_SupplyCapExceeded();
    error RM_BorrowCapExceeded();
    error RM_InvalidLiquidationState();

    // CONSTANTS

    uint256 internal constant CONFIG_SCALE = 60_000; // must fit into a uint16
    uint16 internal constant DEFAULT_BORROW_FACTOR = uint16(0.28 * 60_000);
    uint16 internal constant DEFAULT_INTEREST_FEE = uint16(0.23 * 60_000);
    // Maximum liquidation discount that can be awarded under any conditions.
    uint256 public constant MAXIMUM_LIQUIDATION_DISCOUNT = 0.2 * 1e18;

    // STORAGE

    struct MarketConfig {
        bool activated; // TODO type enum: NOT_ACTIVATED, REGULAR, EXTERNAL, remove isExternal?
        uint8 assetDecimals; // TODO remove if possible
        uint16 collateralFactor;
        uint16 borrowFactor;
        uint32 pauseBitmask;
        uint64 supplyCap; // asset units without decimals, 0 means no cap
        uint64 borrowCap; // asset units without decimals, 0 means no cap
        address interestRateModel; // external market if address(0)
        uint16 interestFee;
    }

    struct OverrideConfig {
        bool enabled;
        uint16 collateralFactor;
    }

    address internal governorAdmin;
    address internal defaultInterestRateModel;
    address internal feeReceiverAddress;

    mapping(address market => MarketConfig) internal markets;
    mapping(address asset => address market) internal underlyingToMarket;

    mapping(address liability => mapping(address collateral => OverrideConfig)) internal overrideLookup;
    mapping(address liability => address[] collaterals) internal overrideCollaterals;
    mapping(address collateral => address[] liabilities) internal overrideLiabilities;

    function resolveMarketConfig(address market) internal view virtual returns (MarketConfig memory);

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert RM_EmptyError();
    }

    function isExternalMarket(MarketConfig storage config) internal view returns (bool) {
        return config.interestRateModel == address(0);
    }
}

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

/// @title GovernanceModule
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An EVault module handling governance, including configuration and fees
abstract contract GovernanceModule is IGovernance, Base, BalanceUtils, BorrowUtils, LTVUtils {
    using TypesLib for uint16;

    // Protocol guarantees
    uint16 internal constant MAX_PROTOCOL_FEE_SHARE = 0.5e4;
    uint16 internal constant GUARANTEED_INTEREST_FEE_MIN = 0.1e4;
    uint16 internal constant GUARANTEED_INTEREST_FEE_MAX = 1e4;

    /// @notice Set a name of the EVault's share token (eToken)
    /// @param newName A new name of the eToken
    event GovSetName(string newName);

    /// @notice Set a symbol of the EVault's share token (eToken)
    /// @param newSymbol A new symbol of the eToken
    event GovSetSymbol(string newSymbol);

    /// @notice Set a governor address for the EVault
    /// @param newGovernorAdmin Address of the new governor
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);

    /// @notice Set a fee receiver address
    /// @param newFeeReceiver Address of the new fee receiver
    event GovSetFeeReceiver(address indexed newFeeReceiver);

    /// @notice Set new LTV configuration for a collateral
    /// @param collateral Address of the collateral
    /// @param targetTimestamp If the LTV is lowered, the timestamp when the ramped liquidation LTV will merge with the `targetLTV`
    /// @param targetLTV The new LTV for the collateral in 1e4 scale
    /// @param rampDuration If the LTV is lowered, duration in seconds, during which the liquidation LTV will be merging with `targetLTV`
    /// @param originalLTV The previous liquidation LTV at the moment a new configuration was set
    event GovSetLTV(
        address indexed collateral, uint48 targetTimestamp, uint16 targetLTV, uint32 rampDuration, uint16 originalLTV
    );

    /// @notice Set an interest rate model contract address
    /// @param newInterestRateModel Address of the new IRM
    event GovSetInterestRateModel(address newInterestRateModel);

    /// @notice Set new hooks configuration
    /// @param newHookTarget Address of the new hook target contract
    /// @param newHookedOps A bitfield of operations to be hooked. See Constants.sol for a list of operations
    event GovSetHookConfig(address indexed newHookTarget, uint32 newHookedOps);

    /// @notice Set new configuration flags
    /// @param newConfigFlags New configuration flags. See Constants.sol for a list of configuration flags
    event GovSetConfigFlags(uint32 newConfigFlags);

    /// @notice Set new caps
    /// @param newSupplyCap New supply cap in AmountCap format
    /// @param newBorrowCap New borrow cap in AmountCap format
    event GovSetCaps(uint16 newSupplyCap, uint16 newBorrowCap);

    /// @notice Set new interest fee
    /// @param newFee New interest fee as percentage in 1e4 scale
    event GovSetInterestFee(uint16 newFee);

    modifier governorOnly() {
        if (msg.sender != vaultStorage.governorAdmin) revert E_Unauthorized();
        _;
    }

    /// @inheritdoc IGovernance
    function governorAdmin() public view virtual reentrantOK returns (address) {
        return vaultStorage.governorAdmin;
    }

    /// @inheritdoc IGovernance
    function feeReceiver() public view virtual reentrantOK returns (address) {
        return vaultStorage.feeReceiver;
    }

    /// @inheritdoc IGovernance
    function interestFee() public view virtual reentrantOK returns (uint16) {
        return vaultStorage.interestFee.toUint16();
    }

    /// @inheritdoc IGovernance
    function interestRateModel() public view virtual reentrantOK returns (address) {
        return vaultStorage.interestRateModel;
    }

    /// @inheritdoc IGovernance
    function protocolConfigAddress() public view virtual reentrantOK returns (address) {
        return address(protocolConfig);
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
    function caps() public view virtual reentrantOK returns (uint16, uint16) {
        return (vaultStorage.supplyCap.toRawUint16(), vaultStorage.borrowCap.toRawUint16());
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
        LTVConfig memory ltv = vaultStorage.ltvLookup[collateral];
        return (ltv.targetTimestamp, ltv.targetLTV.toUint16(), ltv.rampDuration, ltv.originalLTV.toUint16());
    }

    /// @inheritdoc IGovernance
    function LTVList() public view virtual reentrantOK returns (address[] memory) {
        return vaultStorage.ltvList;
    }

    /// @inheritdoc IGovernance
    function hookConfig() public view virtual reentrantOK returns (address, uint32) {
        return (vaultStorage.hookTarget, vaultStorage.hookedOps.toUint32());
    }

    /// @inheritdoc IGovernance
    function configFlags() public view virtual reentrantOK returns (uint32) {
        return (vaultStorage.configFlags.toUint32());
    }

    /// @inheritdoc IGovernance
    function EVC() public view virtual reentrantOK returns (address) {
        return address(evc);
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
    function permit2Address() public view virtual reentrantOK returns (address) {
        return permit2;
    }

    /// @inheritdoc IGovernance
    function convertFees() public virtual nonReentrant {
        (VaultCache memory vaultCache, address account) = initOperation(OP_CONVERT_FEES, CHECKACCOUNT_NONE);

        if (vaultCache.accumulatedFees.isZero()) return;

        (address protocolReceiver, uint16 protocolFee) = protocolConfig.protocolFeeConfig(address(this));
        address governorReceiver = vaultStorage.feeReceiver;

        if (governorReceiver == address(0)) {
            protocolFee = CONFIG_SCALE; // governor forfeits fees
        } else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) {
            protocolFee = MAX_PROTOCOL_FEE_SHARE;
        }

        Shares governorShares = vaultCache.accumulatedFees.mulDiv(CONFIG_SCALE - protocolFee, CONFIG_SCALE);
        Shares protocolShares = vaultCache.accumulatedFees - governorShares;

        // Decrease totalShares because increaseBalance will increase it by that total amount
        vaultStorage.totalShares = vaultCache.totalShares = vaultCache.totalShares - vaultCache.accumulatedFees;

        vaultStorage.accumulatedFees = vaultCache.accumulatedFees = Shares.wrap(0);

        // For the Deposit events in increaseBalance the assets amount is zero - the shares are covered with the accrued interest
        if (!governorShares.isZero()) {
            increaseBalance(vaultCache, governorReceiver, address(0), governorShares, Assets.wrap(0));
        }

        if (!protocolShares.isZero()) {
            increaseBalance(vaultCache, protocolReceiver, address(0), protocolShares, Assets.wrap(0));
        }

        emit ConvertFees(account, protocolReceiver, governorReceiver, protocolShares.toUint(), governorShares.toUint());
    }

    /// @inheritdoc IGovernance
    function setName(string calldata newName) public virtual nonReentrant governorOnly {
        vaultStorage.name = newName;
        emit GovSetName(newName);
    }

    /// @inheritdoc IGovernance
    function setSymbol(string calldata newSymbol) public virtual nonReentrant governorOnly {
        vaultStorage.symbol = newSymbol;
        emit GovSetSymbol(newSymbol);
    }

    /// @inheritdoc IGovernance
    function setGovernorAdmin(address newGovernorAdmin) public virtual nonReentrant governorOnly {
        vaultStorage.governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @inheritdoc IGovernance
    function setFeeReceiver(address newFeeReceiver) public virtual nonReentrant governorOnly {
        vaultStorage.feeReceiver = newFeeReceiver;
        emit GovSetFeeReceiver(newFeeReceiver);
    }

    /// @inheritdoc IGovernance
    function setLTV(address collateral, uint16 ltv, uint32 rampDuration) public virtual nonReentrant governorOnly {
        // self-collateralization is not allowed
        if (collateral == address(this)) revert E_InvalidLTVAsset();

        ConfigAmount newLTVAmount = ltv.toConfigAmount();
        LTVConfig memory origLTV = vaultStorage.ltvLookup[collateral];

        // If new LTV is higher than the previous, or the same, it should take effect immediately
        if (newLTVAmount >= origLTV.getLTV(LTVType.LIQUIDATION) && rampDuration > 0) revert E_LTVRamp();

        LTVConfig memory newLTV = origLTV.setLTV(newLTVAmount, rampDuration);

        vaultStorage.ltvLookup[collateral] = newLTV;

        if (!origLTV.initialized) vaultStorage.ltvList.push(collateral);

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
        vaultStorage.ltvLookup[collateral].clear();

        emit GovSetLTV(collateral, 0, 0, 0, originalLTV);
    }

    /// @inheritdoc IGovernance
    function setInterestRateModel(address newModel) public virtual nonReentrant governorOnly {
        VaultCache memory vaultCache = updateVault();

        vaultStorage.interestRateModel = newModel;
        vaultStorage.interestRate = 0;

        uint256 newInterestRate = computeInterestRate(vaultCache);

        logVaultStatus(vaultCache, newInterestRate);

        emit GovSetInterestRateModel(newModel);
    }

    /// @inheritdoc IGovernance
    function setHookConfig(address newHookTarget, uint32 newHookedOps) public virtual nonReentrant governorOnly {
        vaultStorage.hookTarget = newHookTarget;
        vaultStorage.hookedOps = Flags.wrap(newHookedOps);
        emit GovSetHookConfig(newHookTarget, newHookedOps);
    }

    /// @inheritdoc IGovernance
    function setConfigFlags(uint32 newConfigFlags) public virtual nonReentrant governorOnly {
        vaultStorage.configFlags = Flags.wrap(newConfigFlags);
        emit GovSetConfigFlags(newConfigFlags);
    }

    /// @inheritdoc IGovernance
    function setCaps(uint16 supplyCap, uint16 borrowCap) public virtual nonReentrant governorOnly {
        AmountCap _supplyCap = AmountCap.wrap(supplyCap);
        // Max total assets is a sum of max cash size and max total debt, both Assets type
        if (supplyCap > 0 && _supplyCap.resolve() > 2 * MAX_SANE_AMOUNT) revert E_BadSupplyCap();

        AmountCap _borrowCap = AmountCap.wrap(borrowCap);
        if (borrowCap > 0 && _borrowCap.resolve() > MAX_SANE_AMOUNT) revert E_BadBorrowCap();

        vaultStorage.supplyCap = _supplyCap;
        vaultStorage.borrowCap = _borrowCap;

        emit GovSetCaps(supplyCap, borrowCap);
    }

    /// @inheritdoc IGovernance
    function setInterestFee(uint16 newInterestFee) public virtual nonReentrant governorOnly {
        // Update vault to apply the current interest fee to the pending interest
        VaultCache memory vaultCache = updateVault();
        logVaultStatus(vaultCache, vaultStorage.interestRate);

        // Interest fees in guaranteed range are always allowed, otherwise ask protocolConfig
        if (newInterestFee < GUARANTEED_INTEREST_FEE_MIN || newInterestFee > GUARANTEED_INTEREST_FEE_MAX) {
            if (!protocolConfig.isValidInterestFee(address(this), newInterestFee)) revert E_BadFee();
        }

        vaultStorage.interestFee = newInterestFee.toConfigAmount();

        emit GovSetInterestFee(newInterestFee);
    }
}

/// @dev Deployable module contract
contract Governance is GovernanceModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

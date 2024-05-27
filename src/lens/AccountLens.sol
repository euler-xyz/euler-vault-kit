// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {Errors} from "../EVault/shared/Errors.sol";
import {LensUtils} from "./LensUtils.sol";
import "./LensTypes.sol";

contract AccountLens is LensUtils {
    function getAccountInfo(address account, address vault) public view returns (AccountInfo memory) {
        AccountInfo memory result;

        result.evcAccountInfo = getEVCAccountInfo(IEVault(vault).EVC(), account);
        result.vaultAccountInfo = getVaultAccountInfo(account, vault);
        result.accountRewardInfo = getRewardAccountInfo(account, vault);

        return result;
    }

    function getAccountEnabledVaultsInfo(address evc, address account)
        public
        view
        returns (AccountMultipleVaultsInfo memory)
    {
        AccountMultipleVaultsInfo memory result;

        result.evcAccountInfo = getEVCAccountInfo(evc, account);

        uint256 controllersLength = result.evcAccountInfo.enabledControllers.length;
        uint256 collateralsLength = result.evcAccountInfo.enabledCollaterals.length;

        result.vaultAccountInfo = new VaultAccountInfo[](controllersLength + collateralsLength);
        result.accountRewardInfo = new AccountRewardInfo[](controllersLength + collateralsLength);

        for (uint256 i = 0; i < controllersLength; ++i) {
            result.vaultAccountInfo[i] = getVaultAccountInfo(account, result.evcAccountInfo.enabledControllers[i]);
            result.accountRewardInfo[i] = getRewardAccountInfo(account, result.evcAccountInfo.enabledControllers[i]);
        }

        for (uint256 i = 0; i < collateralsLength; ++i) {
            result.vaultAccountInfo[controllersLength + i] =
                getVaultAccountInfo(account, result.evcAccountInfo.enabledCollaterals[i]);
            result.accountRewardInfo[controllersLength + i] =
                getRewardAccountInfo(account, result.evcAccountInfo.enabledCollaterals[i]);
        }

        return result;
    }

    function getEVCAccountInfo(address evc, address account) public view returns (EVCAccountInfo memory) {
        EVCAccountInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.evc = evc;
        result.account = account;
        result.addressPrefix = IEVC(evc).getAddressPrefix(account);
        result.owner = IEVC(evc).getAccountOwner(account);

        result.isLockdownMode = IEVC(evc).isLockdownMode(result.addressPrefix);
        result.isPermitDisabledMode = IEVC(evc).isPermitDisabledMode(result.addressPrefix);
        result.lastAccountStatusCheckTimestamp = IEVC(evc).getLastAccountStatusCheckTimestamp(account);
        result.enabledControllers = IEVC(evc).getControllers(account);
        result.enabledCollaterals = IEVC(evc).getCollaterals(account);

        return result;
    }

    function getVaultAccountInfo(address account, address vault) public view returns (VaultAccountInfo memory) {
        VaultAccountInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.account = account;
        result.vault = vault;
        result.asset = IEVault(vault).asset();

        result.assetsAccount = IEVault(result.asset).balanceOf(account);
        result.shares = IEVault(vault).balanceOf(account);
        result.assets = IEVault(vault).convertToAssets(result.shares);
        result.borrowed = IEVault(vault).debtOf(account);

        result.assetAllowanceVault = IEVault(result.asset).allowance(account, vault);

        address permit2 = IEVault(vault).permit2Address();
        if (permit2 != address(0)) {
            (result.assetAllowanceVaultPermit2, result.assetAllowanceExpirationVaultPermit2,) =
                IAllowanceTransfer(permit2).allowance(account, result.asset, vault);

            result.assetAllowancePermit2 = IEVault(result.asset).allowance(account, permit2);
        }

        result.balanceForwarderEnabled = IEVault(vault).balanceForwarderEnabled(account);

        address evc = IEVault(vault).EVC();
        result.isController = IEVC(evc).isControllerEnabled(account, vault);
        result.isCollateral = IEVC(evc).isCollateralEnabled(account, vault);

        try IEVault(vault).accountLiquidity(account, false) returns (uint256 _collateralValue, uint256 _liabilityValue)
        {
            result.liquidityInfo.liabilityValue = _liabilityValue;
            result.liquidityInfo.collateralValueBorrowing = _collateralValue;
        } catch {}

        try IEVault(vault).accountLiquidity(account, true) returns (uint256 _collateralValue, uint256) {
            result.liquidityInfo.collateralValueLiquidation = _collateralValue;
        } catch (bytes memory reason) {
            if (bytes4(reason) != Errors.E_NoLiability.selector) result.liquidityInfo.timeToLiquidation = TTL_ERROR;
        }

        try IEVault(vault).accountLiquidityFull(account, false) returns (
            address[] memory _collaterals, uint256[] memory _collateralValues, uint256
        ) {
            result.liquidityInfo.collateralLiquidityBorrowingInfo = new CollateralLiquidityInfo[](_collaterals.length);

            for (uint256 i = 0; i < _collaterals.length; ++i) {
                result.liquidityInfo.collateralLiquidityBorrowingInfo[i].collateral = _collaterals[i];
                result.liquidityInfo.collateralLiquidityBorrowingInfo[i].collateralValue = _collateralValues[i];
            }
        } catch {}

        address[] memory enabledCollaterals;
        uint256[] memory collateralValues;
        try IEVault(vault).accountLiquidityFull(account, true) returns (
            address[] memory _collaterals, uint256[] memory _collateralValues, uint256
        ) {
            enabledCollaterals = _collaterals;
            collateralValues = _collateralValues;

            result.liquidityInfo.collateralLiquidityLiquidationInfo = new CollateralLiquidityInfo[](_collaterals.length);

            for (uint256 i = 0; i < _collaterals.length; ++i) {
                result.liquidityInfo.collateralLiquidityLiquidationInfo[i].collateral = _collaterals[i];
                result.liquidityInfo.collateralLiquidityLiquidationInfo[i].collateralValue = _collateralValues[i];
            }
        } catch (bytes memory reason) {
            if (bytes4(reason) != Errors.E_NoLiability.selector) result.liquidityInfo.timeToLiquidation = TTL_ERROR;
        }

        if (result.liquidityInfo.timeToLiquidation == 0) {
            if (result.liquidityInfo.liabilityValue == 0) {
                // if there's no liability, time to liquidation is infinite
                result.liquidityInfo.timeToLiquidation = TTL_INFINITY;
            } else if (result.liquidityInfo.liabilityValue >= result.liquidityInfo.collateralValueLiquidation) {
                // if liability is greater than or equal to collateral, the account is eligible for liquidation right
                // away
                result.liquidityInfo.timeToLiquidation = TTL_LIQUIDATION;
            } else {
                result.liquidityInfo.timeToLiquidation = calculateTimeToLiquidation(
                    vault, result.liquidityInfo.liabilityValue, enabledCollaterals, collateralValues
                );
            }
        }

        return result;
    }

    function getTimeToLiquidation(address account, address vault) public view returns (int256) {
        address[] memory collaterals;
        uint256[] memory collateralValues;

        // get collateral and liability values
        uint256 collateralValue;
        uint256 liabilityValue;
        try IEVault(vault).accountLiquidity(account, true) returns (uint256 _collateralValue, uint256 _liabilityValue) {
            collateralValue = _collateralValue;
            liabilityValue = _liabilityValue;
        } catch (bytes memory reason) {
            if (bytes4(reason) != Errors.E_NoLiability.selector) return TTL_ERROR;
        }

        // if there's no liability, time to liquidation is infinite
        if (liabilityValue == 0) return TTL_INFINITY;

        // if liability is greater than or equal to collateral, the account is eligible for liquidation right away
        if (liabilityValue >= collateralValue) return TTL_LIQUIDATION;

        // get detailed collateral values
        try IEVault(vault).accountLiquidityFull(account, true) returns (
            address[] memory _collaterals, uint256[] memory _collateralValues, uint256
        ) {
            collaterals = _collaterals;
            collateralValues = _collateralValues;
        } catch (bytes memory reason) {
            if (bytes4(reason) != Errors.E_NoLiability.selector) return TTL_ERROR;
        }

        return calculateTimeToLiquidation(vault, liabilityValue, collaterals, collateralValues);
    }

    function getRewardAccountInfo(address account, address vault) public view returns (AccountRewardInfo memory) {
        AccountRewardInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.account = account;
        result.vault = vault;

        result.balanceTracker = IEVault(vault).balanceTrackerAddress();
        result.balanceForwarderEnabled = IEVault(vault).balanceForwarderEnabled(account);

        if (result.balanceTracker == address(0)) return result;

        result.balance = IRewardStreams(result.balanceTracker).balanceOf(account, vault);

        address[] memory enabledRewards = IRewardStreams(result.balanceTracker).enabledRewards(account, vault);
        result.enabledRewardsInfo = new EnabledRewardInfo[](enabledRewards.length);

        for (uint256 i; i < enabledRewards.length; ++i) {
            result.enabledRewardsInfo[i].reward = enabledRewards[i];

            result.enabledRewardsInfo[i].earnedReward =
                IRewardStreams(result.balanceTracker).earnedReward(account, vault, enabledRewards[i], false);

            result.enabledRewardsInfo[i].earnedRewardRecentForfeited =
                IRewardStreams(result.balanceTracker).earnedReward(account, vault, enabledRewards[i], true);
        }

        return result;
    }
}

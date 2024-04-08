// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
//import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {RPow} from "../EVault/shared/lib/RPow.sol";
import {IIRM, IRMLinearKink} from "../InterestRateModels/IRMLinearKink.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import "../EVault/shared/types/AmountCap.sol";
import "./LensTypes.sol";

contract EVaultLens {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400;
    uint256 internal constant ONE = 1e27;
    uint256 internal constant CONFIG_SCALE = 1e4;

    function getAccountInfo(address account, address vault) public view returns (AccountInfo memory) {
        AccountInfo memory result;

        result.evcAccountInfo = getEVCAccountInfo(IEVault(vault).EVC(), account);
        result.vaultAccountInfo = getVaultAccountInfo(account, vault);
        //result.accountRewardInfo = getRewardAccountInfo(account, vault);

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

        try IEVault(vault).accountLiquidity(account, false) returns (uint256 collateralValue, uint256 liabilityValue) {
            result.liquidityInfo.liabilityValue = liabilityValue;
            result.liquidityInfo.collateralValueBorrowing = collateralValue;
        } catch {}

        try IEVault(vault).accountLiquidity(account, true) returns (uint256 collateralValue, uint256) {
            result.liquidityInfo.collateralValueLiquidation = collateralValue;
        } catch {}

        try IEVault(vault).accountLiquidityFull(account, false) returns (
            address[] memory collaterals, uint256[] memory collateralValues, uint256
        ) {
            result.liquidityInfo.collateralLiquidityBorrowingInfo = new CollateralLiquidityInfo[](collaterals.length);

            for (uint256 i = 0; i < collaterals.length; ++i) {
                result.liquidityInfo.collateralLiquidityBorrowingInfo[i].collateral = collaterals[i];
                result.liquidityInfo.collateralLiquidityBorrowingInfo[i].collateralValue = collateralValues[i];
            }
        } catch {}

        try IEVault(vault).accountLiquidityFull(account, true) returns (
            address[] memory collaterals, uint256[] memory collateralValues, uint256
        ) {
            result.liquidityInfo.collateralLiquidityLiquidationInfo = new CollateralLiquidityInfo[](collaterals.length);

            for (uint256 i = 0; i < collaterals.length; ++i) {
                result.liquidityInfo.collateralLiquidityLiquidationInfo[i].collateral = collaterals[i];
                result.liquidityInfo.collateralLiquidityLiquidationInfo[i].collateralValue = collateralValues[i];
            }
        } catch {}

        return result;
    }

    function getVaultInfo(address vault) public view returns (VaultInfo memory) {
        VaultInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.vault = vault;
        result.vaultName = IEVault(vault).name();
        result.vaultSymbol = IEVault(vault).symbol();
        result.vaultDecimals = IEVault(vault).decimals();

        result.asset = IEVault(vault).asset();
        result.assetName = getStringOrBytes32(result.asset, IEVault(vault).name.selector);
        result.assetSymbol = getStringOrBytes32(result.asset, IEVault(vault).symbol.selector);
        result.assetDecimals = getDecimals(result.asset);

        result.unitOfAccount = IEVault(vault).unitOfAccount();
        result.unitOfAccountName = getStringOrBytes32(result.unitOfAccount, IEVault(vault).name.selector);
        result.unitOfAccountSymbol = getStringOrBytes32(result.unitOfAccount, IEVault(vault).symbol.selector);
        result.unitOfAccountDecimals = getDecimals(result.unitOfAccount);

        result.totalShares = IEVault(vault).totalSupply();
        result.totalCash = IEVault(vault).cash();
        result.totalBorrowed = IEVault(vault).totalBorrows();
        result.totalAssets = IEVault(vault).totalAssets();

        result.accumulatedFeesShares = IEVault(vault).accumulatedFees();
        result.accumulatedFeesAssets = IEVault(vault).accumulatedFeesAssets();

        result.governorFeeReceiver = IEVault(vault).feeReceiver();
        result.protocolFeeReceiver = IEVault(vault).protocolFeeReceiver();
        result.protocolFeeShare = IEVault(vault).protocolFeeShare();

        result.interestFee = IEVault(vault).interestFee();
        result.borrowInterestRateSPY = IEVault(vault).interestRate();
        (result.supplyInterestRateSPY, result.borrowInterestRateAPY, result.supplyInterestRateAPY) =
        computeInterestRates(result.borrowInterestRateSPY, result.totalCash, result.totalBorrowed, result.interestFee);

        (result.hookTarget, result.hookedOperations) = IEVault(vault).hookConfig();

        (result.supplyCap, result.borrowCap) = IEVault(vault).caps();
        result.supplyCap = AmountCapLib.toUint(AmountCap.wrap(uint16(result.supplyCap)));
        result.borrowCap = AmountCapLib.toUint(AmountCap.wrap(uint16(result.borrowCap)));

        result.dToken = IEVault(vault).dToken();
        result.oracle = IEVault(vault).oracle();
        result.interestRateModel = IEVault(vault).interestRateModel();

        result.evc = IEVault(vault).EVC();
        result.protocolConfig = IEVault(vault).protocolConfigAddress();
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();
        result.permit2 = IEVault(vault).permit2Address();

        result.creator = IEVault(vault).creator();
        result.governorAdmin = IEVault(vault).governorAdmin();

        address[] memory collaterals = IEVault(vault).LTVList();
        LTVInfo[] memory collateralLTVInfo = new LTVInfo[](collaterals.length);
        uint256 numberOfRecognizedCollaterals = 0;

        for (uint256 i = 0; i < collaterals.length; ++i) {
            collateralLTVInfo[i].collateral = collaterals[i];
            collateralLTVInfo[i].liquidationLTV = IEVault(vault).liquidationLTV(collaterals[i]);

            (
                collateralLTVInfo[i].targetTimestamp,
                collateralLTVInfo[i].borrowingLTV,
                collateralLTVInfo[i].rampDuration,
                collateralLTVInfo[i].originalLTV
            ) = IEVault(vault).LTVFull(collaterals[i]);

            if (collateralLTVInfo[i].targetTimestamp != 0) {
                ++numberOfRecognizedCollaterals;
            }
        }

        result.collateralLTVInfo = new LTVInfo[](numberOfRecognizedCollaterals);

        for (uint256 i = 0; i < collaterals.length; ++i) {
            if (collateralLTVInfo[i].targetTimestamp != 0) {
                result.collateralLTVInfo[i] = collateralLTVInfo[i];
            }
        }

        if (result.oracle != address(0)) {
            ControllerAssetPriceInfo memory priceInfo = getControllerAssetPriceInfo(vault, result.asset);

            result.liabilityPriceInfo.liability = priceInfo.asset;
            result.liabilityPriceInfo.unitOfAccount = priceInfo.unitOfAccount;
            result.liabilityPriceInfo.amountIn = priceInfo.amountIn;
            result.liabilityPriceInfo.amountOut = priceInfo.amountOutAsk;

            result.collateralPriceInfo = new CollateralPriceInfo[](numberOfRecognizedCollaterals);

            for (uint256 i = 0; i < result.collateralLTVInfo.length; ++i) {
                priceInfo = getControllerAssetPriceInfo(vault, result.collateralLTVInfo[i].collateral);

                result.collateralPriceInfo[i].collateral = priceInfo.asset;
                result.collateralPriceInfo[i].unitOfAccount = priceInfo.unitOfAccount;
                result.collateralPriceInfo[i].amountIn = priceInfo.amountIn;
                result.collateralPriceInfo[i].amountOutNotAdjusted = priceInfo.amountOutBid;
                result.collateralPriceInfo[i].amountOutBorrowing =
                    priceInfo.amountOutBid * result.collateralLTVInfo[i].borrowingLTV / CONFIG_SCALE;
                result.collateralPriceInfo[i].amountOutLiquidation =
                    priceInfo.amountOutBid * result.collateralLTVInfo[i].liquidationLTV / CONFIG_SCALE;
            }
        }

        return result;
    }
    /*
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

    function getRewardInfo(address vault, address reward, uint256 numberOfEpochs)
        public
        view
        returns (RewardInfo memory)
    {
        RewardInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.vault = vault;
        result.reward = reward;
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();

        if (result.balanceTracker == address(0)) return result;

        result.epochDuration = IRewardStreams(result.balanceTracker).EPOCH_DURATION();
        result.currentEpoch = IRewardStreams(result.balanceTracker).currentEpoch();
        result.totalRewardEligible = IRewardStreams(result.balanceTracker).totalRewardedEligible(vault, reward);
        result.totalRewardRegistered = IRewardStreams(result.balanceTracker).totalRewardRegistered(vault, reward);
        result.totalRewardClaimed = IRewardStreams(result.balanceTracker).totalRewardClaimed(vault, reward);

        result.epochInfoPrevious = new RewardAmountInfo[](numberOfEpochs);
        result.epochInfoUpcoming = new RewardAmountInfo[](numberOfEpochs);

        for (uint256 i; i < 2 * numberOfEpochs; ++i) {
            if (i < numberOfEpochs) {
                uint256 index = i;
                result.epochInfoPrevious[index].epoch = result.currentEpoch - numberOfEpochs + i;

                result.epochInfoPrevious[index].epochStart = IRewardStreams(result.balanceTracker)
                    .getEpochStartTimestamp(uint48(result.epochInfoPrevious[index].epoch));

                result.epochInfoPrevious[index].epochEnd = IRewardStreams(result.balanceTracker)
                    .getEpochEndTimestamp(uint48(result.epochInfoPrevious[index].epoch));

                result.epochInfoPrevious[index].rewardAmount = IRewardStreams(result.balanceTracker).rewardAmount(
                    vault, reward, uint48(result.epochInfoPrevious[index].epoch)
                );
            } else {
                uint256 index = i - numberOfEpochs;
                result.epochInfoUpcoming[index].epoch = result.currentEpoch - numberOfEpochs + i;

                result.epochInfoUpcoming[index].epochStart = IRewardStreams(result.balanceTracker)
                    .getEpochStartTimestamp(uint48(result.epochInfoUpcoming[index].epoch));

                result.epochInfoUpcoming[index].epochEnd = IRewardStreams(result.balanceTracker)
                    .getEpochEndTimestamp(uint48(result.epochInfoUpcoming[index].epoch));

                result.epochInfoUpcoming[index].rewardAmount = IRewardStreams(result.balanceTracker).rewardAmount(
                    vault, reward, uint48(result.epochInfoUpcoming[index].epoch)
                );
            }
        }

        return result;
    }
    */

    function getVaultInterestRateModelInfo(address vault, uint256[] memory cash, uint256[] memory borrows)
        public
        view
        returns (VaultInterestRateModelInfo memory)
    {
        require(cash.length == borrows.length, "EVaultLens: invalid input");

        VaultInterestRateModelInfo memory result;

        result.vault = vault;
        result.interestRateModel = IEVault(vault).interestRateModel();

        if (result.interestRateModel == address(0)) return result;

        uint256 interestFee = IEVault(vault).interestFee();
        result.apyInfo = new APYInfo[](cash.length);

        for (uint256 i = 0; i < cash.length; ++i) {
            result.apyInfo[i].cash = cash[i];
            result.apyInfo[i].borrows = borrows[i];

            uint256 borrowSPY = IIRM(result.interestRateModel).computeInterestRateView(
                vault, result.apyInfo[i].cash, result.apyInfo[i].borrows
            );

            (, result.apyInfo[i].borrowInterestRateAPY, result.apyInfo[i].supplyInterestRateAPY) =
                computeInterestRates(borrowSPY, cash[i], borrows[i], interestFee);
        }

        return result;
    }

    function getVaultKinkInterestRateModelInfo(address vault) public view returns (VaultInterestRateModelInfo memory) {
        address interestRateModel = IEVault(vault).interestRateModel();

        if (interestRateModel == address(0)) {
            VaultInterestRateModelInfo memory result;
            result.vault = vault;
            result.interestRateModel = address(0);
            return result;
        }

        uint256[] memory cash = new uint256[](3);
        uint256[] memory borrows = new uint256[](3);
        uint256 kink = IRMLinearKink(interestRateModel).kink();

        cash[0] = type(uint32).max;
        cash[1] = type(uint32).max - kink;
        cash[2] = 0;
        borrows[0] = 0;
        borrows[1] = kink;
        borrows[2] = type(uint32).max;

        return getVaultInterestRateModelInfo(vault, cash, borrows);
    }

    function getControllerAssetPriceInfo(address controller, address asset)
        public
        view
        returns (ControllerAssetPriceInfo memory)
    {
        ControllerAssetPriceInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

        result.controller = controller;
        result.oracle = IEVault(controller).oracle();
        result.asset = asset;
        result.unitOfAccount = IEVault(controller).unitOfAccount();

        if (result.oracle == address(0)) return result;

        result.amountIn = 10 ** getDecimals(asset);
        result.amountOutMid = IPriceOracle(result.oracle).getQuote(result.amountIn, asset, result.unitOfAccount);
        (result.amountOutBid, result.amountOutAsk) =
            IPriceOracle(result.oracle).getQuotes(result.amountIn, asset, result.unitOfAccount);

        return result;
    }

    /// @dev for tokens like MKR which return bytes32 on name() or symbol()
    function getStringOrBytes32(address contractAddress, bytes4 selector) private view returns (string memory) {
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(selector));

        return success ? result.length == 32 ? string(abi.encodePacked(result)) : abi.decode(result, (string)) : "";
    }

    function getDecimals(address contractAddress) private view returns (uint8) {
        (bool success, bytes memory data) = contractAddress.staticcall(abi.encodeCall(IEVault(contractAddress).decimals, ()));
        
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function computeInterestRates(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        private
        pure
        returns (uint256 supplySPY, uint256 borrowAPY, uint256 supplyAPY)
    {
        uint256 totalAssets = cash + borrows;
        bool overflowBorrow;
        bool overflowSupply;

        supplySPY =
            totalAssets == 0 ? 0 : borrowSPY * borrows * (CONFIG_SCALE - interestFee) / totalAssets / CONFIG_SCALE;
        (borrowAPY, overflowBorrow) = RPow.rpow(borrowSPY + ONE, SECONDS_PER_YEAR, ONE);
        (supplyAPY, overflowSupply) = RPow.rpow(supplySPY + ONE, SECONDS_PER_YEAR, ONE);

        if (overflowBorrow || overflowSupply) return (supplySPY, 0, 0);

        borrowAPY -= ONE;
        supplyAPY -= ONE;
    }
}

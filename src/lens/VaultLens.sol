// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IEVault} from "../EVault/IEVault.sol";
import {IIRM, IRMLinearKink} from "../InterestRateModels/IRMLinearKink.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {LensUtils} from "./LensUtils.sol";
import "../EVault/shared/types/AmountCap.sol";
import "./LensTypes.sol";

contract VaultLens is LensUtils {
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

        (result.hookTarget, result.hookedOperations) = IEVault(vault).hookConfig();

        result.maxLiquidationDiscount = IEVault(vault).maxLiquidationDiscount();
        result.liquidationCoolOffTime = IEVault(vault).liquidationCoolOffTime();

        (result.supplyCap, result.borrowCap) = IEVault(vault).caps();
        result.supplyCap = AmountCapLib.toRawUint16(AmountCap.wrap(uint16(result.supplyCap)));
        result.borrowCap = AmountCapLib.toRawUint16(AmountCap.wrap(uint16(result.borrowCap)));

        result.dToken = IEVault(vault).dToken();
        result.oracle = IEVault(vault).oracle();
        result.interestRateModel = IEVault(vault).interestRateModel();

        result.evc = IEVault(vault).EVC();
        result.protocolConfig = IEVault(vault).protocolConfigAddress();
        result.balanceTracker = IEVault(vault).balanceTrackerAddress();
        result.permit2 = IEVault(vault).permit2Address();

        result.creator = IEVault(vault).creator();
        result.governorAdmin = IEVault(vault).governorAdmin();

        uint256[] memory cash = new uint256[](1);
        uint256[] memory borrows = new uint256[](1);
        cash[0] = result.totalCash;
        borrows[0] = result.totalBorrowed;
        result.irmInfo = getVaultInterestRateModelInfo(vault, cash, borrows);

        address[] memory collaterals = IEVault(vault).LTVList();
        LTVInfo[] memory collateralLTVInfo = new LTVInfo[](collaterals.length);
        uint256 numberOfRecognizedCollaterals = 0;

        for (uint256 i = 0; i < collaterals.length; ++i) {
            collateralLTVInfo[i].collateral = collaterals[i];

            (
                collateralLTVInfo[i].borrowLTV,
                collateralLTVInfo[i].liquidationLTV,
                collateralLTVInfo[i].initialLiquidationLTV,
                collateralLTVInfo[i].targetTimestamp,
                collateralLTVInfo[i].rampDuration
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

        result.liabilityPriceInfo = getControllerAssetPriceInfo(vault, result.asset);

        result.collateralPriceInfo = new AssetPriceInfo[](numberOfRecognizedCollaterals);

        for (uint256 i = 0; i < result.collateralLTVInfo.length; ++i) {
            result.collateralPriceInfo[i] = getControllerAssetPriceInfo(vault, result.collateralLTVInfo[i].collateral);
        }

        return result;
    }

    function getRewardVaultInfo(address vault, address reward, uint256 numberOfEpochs)
        public
        view
        returns (VaultRewardInfo memory)
    {
        VaultRewardInfo memory result;

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
            uint48 epoch = uint48(result.currentEpoch - numberOfEpochs + i);

            if (i < numberOfEpochs) {
                uint256 index = i;

                result.epochInfoPrevious[index].epoch = epoch;

                result.epochInfoPrevious[index].epochStart =
                    IRewardStreams(result.balanceTracker).getEpochStartTimestamp(epoch);

                result.epochInfoPrevious[index].epochEnd =
                    IRewardStreams(result.balanceTracker).getEpochEndTimestamp(epoch);

                result.epochInfoPrevious[index].rewardAmount =
                    IRewardStreams(result.balanceTracker).rewardAmount(vault, reward, epoch);
            } else {
                uint256 index = i - numberOfEpochs;

                result.epochInfoUpcoming[index].epoch = epoch;

                result.epochInfoUpcoming[index].epochStart =
                    IRewardStreams(result.balanceTracker).getEpochStartTimestamp(epoch);

                result.epochInfoUpcoming[index].epochEnd =
                    IRewardStreams(result.balanceTracker).getEpochEndTimestamp(epoch);

                result.epochInfoUpcoming[index].rewardAmount =
                    IRewardStreams(result.balanceTracker).rewardAmount(vault, reward, epoch);
            }
        }

        return result;
    }

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

            result.apyInfo[i].borrowInterestRateSPY = IIRM(result.interestRateModel).computeInterestRateView(
                vault, result.apyInfo[i].cash, result.apyInfo[i].borrows
            );

            (
                result.apyInfo[i].supplyInterestRateSPY,
                result.apyInfo[i].borrowInterestRateAPY,
                result.apyInfo[i].supplyInterestRateAPY
            ) = computeInterestRates(result.apyInfo[i].borrowInterestRateSPY, cash[i], borrows[i], interestFee);
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
        returns (AssetPriceInfo memory)
    {
        AssetPriceInfo memory result;

        result.timestamp = block.timestamp;
        result.blockNumber = block.number;

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
}

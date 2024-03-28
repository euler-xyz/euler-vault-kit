// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Utils} from "./Utils.s.sol";
import "../src/lens/EVaultLens.sol";

contract Lens is Utils {
    function run() public {
        string memory json = getConfig("03_Lens", "Lens.json");
        bytes memory configLensBytes = vm.parseJson(json, ".lens");
        address lens = abi.decode(configLensBytes, (address));
        address vault = vm.parseAddress(vm.prompt("Enter the vault address: "));
        string memory tryAccount = vm.prompt("Enter the account address (if needed): ");

        if (bytes(tryAccount).length != 0) {
            AccountInfo memory accountInfo = EVaultLens(lens).getAccountInfo(vm.parseAddress(tryAccount), vault);

            string memory object = vm.serializeUint("evcAccountInfo", "timestamp", accountInfo.evcAccountInfo.timestamp);
            object = vm.serializeUint("evcAccountInfo", "blockNumber", accountInfo.evcAccountInfo.blockNumber);
            object = vm.serializeAddress("evcAccountInfo", "evc", accountInfo.evcAccountInfo.evc);
            object = vm.serializeAddress("evcAccountInfo", "account", accountInfo.evcAccountInfo.account);
            object = vm.serializeBytes32(
                "evcAccountInfo", "addressPrefix", bytes32(accountInfo.evcAccountInfo.addressPrefix)
            );
            object = vm.serializeAddress("evcAccountInfo", "owner", accountInfo.evcAccountInfo.owner);
            object = vm.serializeBool("evcAccountInfo", "isLockdownMode", accountInfo.evcAccountInfo.isLockdownMode);
            object = vm.serializeBool(
                "evcAccountInfo", "isPermitDisabledMode", accountInfo.evcAccountInfo.isPermitDisabledMode
            );
            object = vm.serializeAddress(
                "evcAccountInfo", "enabledControllers", accountInfo.evcAccountInfo.enabledControllers
            );
            object = vm.serializeAddress(
                "evcAccountInfo", "enabledCollaterals", accountInfo.evcAccountInfo.enabledCollaterals
            );

            string memory object2 =
                vm.serializeUint("vaultAccountInfo", "timestamp", accountInfo.vaultAccountInfo.timestamp);
            object2 = vm.serializeUint("vaultAccountInfo", "blockNumber", accountInfo.vaultAccountInfo.blockNumber);
            object2 = vm.serializeAddress("vaultAccountInfo", "account", accountInfo.vaultAccountInfo.account);
            object2 = vm.serializeAddress("vaultAccountInfo", "vault", accountInfo.vaultAccountInfo.vault);
            object2 = vm.serializeAddress("vaultAccountInfo", "asset", accountInfo.vaultAccountInfo.asset);
            object2 = vm.serializeUint("vaultAccountInfo", "assetsAccount", accountInfo.vaultAccountInfo.assetsAccount);
            object2 = vm.serializeUint("vaultAccountInfo", "shares", accountInfo.vaultAccountInfo.shares);
            object2 = vm.serializeUint("vaultAccountInfo", "assets", accountInfo.vaultAccountInfo.assets);
            object2 = vm.serializeUint("vaultAccountInfo", "borrowed", accountInfo.vaultAccountInfo.borrowed);
            object2 = vm.serializeUint("vaultAccountInfo", "maxDeposit", accountInfo.vaultAccountInfo.maxDeposit);
            object2 = vm.serializeUint("vaultAccountInfo", "maxMint", accountInfo.vaultAccountInfo.maxMint);
            object2 = vm.serializeUint("vaultAccountInfo", "maxWithdraw", accountInfo.vaultAccountInfo.maxWithdraw);
            object2 = vm.serializeUint("vaultAccountInfo", "maxRedeem", accountInfo.vaultAccountInfo.maxRedeem);
            object2 = vm.serializeUint(
                "vaultAccountInfo", "assetAllowanceVault", accountInfo.vaultAccountInfo.assetAllowanceVault
            );
            object2 = vm.serializeUint(
                "vaultAccountInfo",
                "assetAllowanceVaultPermit2",
                accountInfo.vaultAccountInfo.assetAllowanceVaultPermit2
            );
            object2 = vm.serializeUint(
                "vaultAccountInfo",
                "assetAllowanceExpirationVaultPermit2",
                accountInfo.vaultAccountInfo.assetAllowanceExpirationVaultPermit2
            );
            object2 = vm.serializeUint(
                "vaultAccountInfo", "assetAllowancePermit2", accountInfo.vaultAccountInfo.assetAllowancePermit2
            );
            object2 = vm.serializeBool(
                "vaultAccountInfo", "balanceForwarderEnabled", accountInfo.vaultAccountInfo.balanceForwarderEnabled
            );
            object2 = vm.serializeBool("vaultAccountInfo", "isController", accountInfo.vaultAccountInfo.isController);
            object2 = vm.serializeBool("vaultAccountInfo", "isCollateral", accountInfo.vaultAccountInfo.isCollateral);

            string memory object3 = vm.serializeUint(
                "liquidityInfo", "liabilityValue", accountInfo.vaultAccountInfo.liquidityInfo.liabilityValue
            );
            object3 = vm.serializeUint(
                "liquidityInfo",
                "collateralValueBorrowing",
                accountInfo.vaultAccountInfo.liquidityInfo.collateralValueBorrowing
            );
            object3 = vm.serializeUint(
                "liquidityInfo",
                "collateralValueLiquidation",
                accountInfo.vaultAccountInfo.liquidityInfo.collateralValueLiquidation
            );
            object2 = vm.serializeString("vaultAccountInfo", "liquidityInfo", object3);

            string memory obj = vm.serializeString("", "evcAccountInfo", object);
            obj = vm.serializeString("", "vaultAccountInfo", object2);

            vm.writeJson(obj, string.concat(vm.projectRoot(), "/script/output/03_Lens/Account.json"));
        }

        {
            VaultInfo memory vaultInfo = EVaultLens(lens).getVaultInfo(vault);

            string memory obj = vm.serializeUint("", "timestamp", vaultInfo.timestamp);
            obj = vm.serializeUint("", "blockNumber", vaultInfo.blockNumber);
            obj = vm.serializeAddress("", "vault", vaultInfo.vault);
            obj = vm.serializeString("", "asset", vaultInfo.vaultName);
            obj = vm.serializeString("", "vaultSymbol", vaultInfo.vaultSymbol);
            obj = vm.serializeUint("", "vaultDecimals", vaultInfo.vaultDecimals);
            obj = vm.serializeAddress("", "asset", vaultInfo.asset);
            obj = vm.serializeString("", "assetName", vaultInfo.assetName);
            obj = vm.serializeString("", "assetSymbol", vaultInfo.assetSymbol);
            obj = vm.serializeUint("", "assetDecimals", vaultInfo.assetDecimals);
            obj = vm.serializeUint("", "totalShares", vaultInfo.totalShares);
            obj = vm.serializeUint("", "totalCash", vaultInfo.totalCash);
            obj = vm.serializeUint("", "totalBorrowed", vaultInfo.totalBorrowed);
            obj = vm.serializeUint("", "totalAssets", vaultInfo.totalAssets);
            obj = vm.serializeUint("", "accumulatedFeesShares", vaultInfo.accumulatedFeesShares);
            obj = vm.serializeUint("", "accumulatedFeesAssets", vaultInfo.accumulatedFeesAssets);
            obj = vm.serializeAddress("", "governorFeeReceiver", vaultInfo.governorFeeReceiver);
            obj = vm.serializeAddress("", "protocolFeeReceiver", vaultInfo.protocolFeeReceiver);
            obj = vm.serializeUint("", "protocolFeeShare", vaultInfo.protocolFeeShare);
            obj = vm.serializeUint("", "interestFee", vaultInfo.interestFee);
            obj = vm.serializeUint("", "borrowInterestRateSPY", vaultInfo.borrowInterestRateSPY);
            obj = vm.serializeUint("", "borrowInterestRateAPY", vaultInfo.borrowInterestRateAPY);
            obj = vm.serializeUint("", "supplyInterestRateSPY", vaultInfo.supplyInterestRateSPY);
            obj = vm.serializeUint("", "supplyInterestRateAPY", vaultInfo.supplyInterestRateAPY);
            obj = vm.serializeUint("", "hookedOperations", vaultInfo.hookedOperations);
            obj = vm.serializeUint("", "supplyCap", vaultInfo.supplyCap);
            obj = vm.serializeUint("", "borrowCap", vaultInfo.borrowCap);
            obj = vm.serializeAddress("", "dToken", vaultInfo.dToken);
            obj = vm.serializeAddress("", "unitOfAccount", vaultInfo.unitOfAccount);
            obj = vm.serializeAddress("", "oracle", vaultInfo.oracle);
            obj = vm.serializeAddress("", "interestRateModel", vaultInfo.interestRateModel);
            obj = vm.serializeAddress("", "hookTarget", vaultInfo.hookTarget);
            obj = vm.serializeAddress("", "evc", vaultInfo.evc);
            obj = vm.serializeAddress("", "protocolConfig", vaultInfo.protocolConfig);
            obj = vm.serializeAddress("", "balanceTracker", vaultInfo.balanceTracker);
            obj = vm.serializeAddress("", "permit2", vaultInfo.permit2);
            obj = vm.serializeAddress("", "creator", vaultInfo.creator);
            obj = vm.serializeAddress("", "governorAdmin", vaultInfo.governorAdmin);

            string memory object =
                vm.serializeAddress("liabilityPriceInfo", "liability", vaultInfo.liabilityPriceInfo.liability);
            object =
                vm.serializeAddress("liabilityPriceInfo", "unitOfAccount", vaultInfo.liabilityPriceInfo.unitOfAccount);
            object = vm.serializeUint("liabilityPriceInfo", "amountIn", vaultInfo.liabilityPriceInfo.amountIn);
            object = vm.serializeUint("liabilityPriceInfo", "amountOut", vaultInfo.liabilityPriceInfo.amountOut);

            string memory object2;
            for (uint256 i = 0; i < vaultInfo.collateralLTVInfo.length; ++i) {
                string memory key = string.concat("collateral", vm.toString(i));
                string memory object22 =
                    vm.serializeAddress(key, "collateral", vaultInfo.collateralLTVInfo[i].collateral);
                object22 = vm.serializeUint(key, "liquidationLTV", vaultInfo.collateralLTVInfo[i].liquidationLTV);
                object22 = vm.serializeUint(key, "borrowingLTV", vaultInfo.collateralLTVInfo[i].borrowingLTV);
                object22 = vm.serializeUint(key, "originalLTV", vaultInfo.collateralLTVInfo[i].originalLTV);
                object22 = vm.serializeUint(key, "targetTimestamp", vaultInfo.collateralLTVInfo[i].targetTimestamp);
                object22 = vm.serializeUint(key, "rampDuration", vaultInfo.collateralLTVInfo[i].rampDuration);
                object2 = vm.serializeString("collateralLTVInfo", key, object22);
            }

            string memory object3;
            for (uint256 i = 0; i < vaultInfo.collateralPriceInfo.length; ++i) {
                string memory key = string.concat("collateral", vm.toString(i));
                string memory object33 =
                    vm.serializeAddress(key, "collateral", vaultInfo.collateralPriceInfo[i].collateral);
                object33 = vm.serializeAddress(key, "unitOfAccount", vaultInfo.collateralPriceInfo[i].unitOfAccount);
                object33 = vm.serializeUint(key, "amountIn", vaultInfo.collateralPriceInfo[i].amountIn);
                object33 =
                    vm.serializeUint(key, "amountOutNotAdjusted", vaultInfo.collateralPriceInfo[i].amountOutNotAdjusted);
                object33 =
                    vm.serializeUint(key, "amountOutBorrowing", vaultInfo.collateralPriceInfo[i].amountOutBorrowing);
                object33 =
                    vm.serializeUint(key, "amountOutLiquidation", vaultInfo.collateralPriceInfo[i].amountOutLiquidation);
                object3 = vm.serializeString("collateralPriceInfo", key, object33);
            }

            obj = vm.serializeString("", "liabilityPriceInfo", object);
            obj = vm.serializeString("", "collateralLTVInfo", object2);
            obj = vm.serializeString("", "collateralPriceInfo", object3);

            vm.writeJson(obj, string.concat(vm.projectRoot(), "/script/output/03_Lens/Vault.json"));
        }
    }
}

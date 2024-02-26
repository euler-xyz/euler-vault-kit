// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IFees} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";
import {SafeERC20Lib} from "../shared/lib/SafeERC20Lib.sol";

import "../shared/types/Types.sol";

abstract contract FeesModule is IFees, Base, BalanceUtils {
    using TypesLib for uint256;
    using SafeERC20Lib for IERC20;

    /// @inheritdoc IFees
    function feesBalance() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().feesBalance.toUint();
    }

    /// @inheritdoc IFees
    function feesBalanceUnderlying() external view virtual nonReentrantView returns (uint256) {
        MarketCache memory marketCache = loadMarket();

        return marketCache.feesBalance.toAssetsDown(marketCache).toUint();
    }

    /// @inheritdoc IFees
    function interestFee() external view virtual reentrantOK returns (uint16) {
        return marketStorage.interestFee;
    }

    /// @inheritdoc IFees
    function protocolFeeShare() external view virtual reentrantOK returns (uint256) {
        (, uint256 protocolShare) = protocolConfig.feeConfig(address(this));
        return protocolShare;
    }

    /// @inheritdoc IFees
    function protocolFeeReceiver() external view virtual reentrantOK returns (address) {
        (address protocolReceiver,) = protocolConfig.feeConfig(address(this));
        return protocolReceiver;
    }

    /// @inheritdoc IFees
    function convertFees() external virtual nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, ACCOUNTCHECK_NONE);

        // Decrease totalShares because increaseBalance will increase it by that total amount
        marketStorage.totalShares =
            marketCache.totalShares = marketCache.totalShares - marketCache.feesBalance.toShares();

        (address protocolReceiver, uint256 protocolFee) = protocolConfig.feeConfig(address(this));
        address feeReceiver = marketStorage.feeReceiver;

        if (feeReceiver == address(0)) protocolFee = 1e18; // governor forfeits fees
        else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) protocolFee = MAX_PROTOCOL_FEE_SHARE;

        Fees currentFeesBalance = marketStorage.feesBalance;
        Shares governorShares = currentFeesBalance.mulDiv(1e18 - protocolFee, 1e18).toShares();
        Shares protocolShares = currentFeesBalance.toShares() - governorShares;
        marketStorage.feesBalance = Fees.wrap(0);

        increaseBalance(
            marketCache, feeReceiver, address(0), governorShares, governorShares.toAssetsDown(marketCache)
        ); // TODO confirm address(0)
        increaseBalance(
            marketCache, protocolReceiver, address(0), protocolShares, protocolShares.toAssetsDown(marketCache)
        );

        emit ConvertFees(
            account,
            protocolReceiver,
            feeReceiver,
            protocolShares.toAssetsDown(marketCache).toUint(),
            governorShares.toAssetsDown(marketCache).toUint()
        );
    }

    /// @inheritdoc IFees
    function skimAssets() external virtual nonReentrant {
        (address admin, address receiver) = protocolConfig.skimConfig(address(this));
        if (msg.sender != admin) revert E_Unauthorized();
        if (receiver == address(0) || receiver == address(this)) revert E_BadAddress();

        (IERC20 asset,,) = ProxyUtils.metadata();

        uint256 balance = asset.callBalanceOf(address(this));
        uint256 poolSize = marketStorage.poolSize.toUint();
        if (balance > poolSize) {
            uint256 amount = balance - poolSize;
            asset.transfer(receiver, amount);
            emit SkimAssets(admin, receiver, amount);
        }
    }
}

contract FeesInstance is FeesModule {
    constructor(address evc, address protocolConfig, address balanceTracker) Base(evc, protocolConfig, balanceTracker) {}
}

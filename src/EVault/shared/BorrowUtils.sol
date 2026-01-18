// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Base} from "./Base.sol";
import {DToken} from "../DToken.sol";
import {IIRM} from "../../InterestRateModels/IIRM.sol";
import {RPow} from "./lib/RPow.sol";

import "./types/Types.sol";
import {UserBorrowCache} from "./types/UserBorrowCache.sol";

/// @title BorrowUtils
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Utilities for tracking debt and interest rates
abstract contract BorrowUtils is Base {
    /// @notice Get current owed amount including base interest and risk premium
    function getCurrentOwed(VaultCache memory vaultCache, address account) internal view returns (Owed) {
        return loadUserBorrow(vaultCache, account).newOwed;
    }

    /// @notice Load user borrow state and compute current owed (view only, no state changes)
    function loadUserBorrow(VaultCache memory vaultCache, address account)
        internal
        view
        returns (UserBorrowCache memory userCache)
    {
        UserStorage storage user = vaultStorage.users[account];

        userCache.account = account;
        userCache.prevOwed = user.getOwed();
        userCache.newOwed = userCache.prevOwed;
        userCache.premiumInterest = Owed.wrap(0);
        userCache.premiumAccumulator = 1e27;

        if (!userCache.prevOwed.isZero()) {
            Owed baseOwed = userCache.prevOwed.mulDiv(vaultCache.interestAccumulator, user.interestAccumulator);
            
            userCache.newOwed = baseOwed;
            userCache.premiumAccumulator = user.premiumAccumulator;

            uint256 premiumRate = vaultStorage.ltvLookup[user.designatedCollateral].riskPremium;

            if (premiumRate != 0) {
                uint256 deltaT = block.timestamp - user.premiumLastUpdate;

                if (deltaT > 0) {
                    unchecked {
                        (uint256 multiplier, bool overflow) = RPow.rpow(premiumRate + 1e27, deltaT, 1e27);

                        if (!overflow) {
                            uint256 intermediate = userCache.premiumAccumulator * multiplier;
                            if (userCache.premiumAccumulator == intermediate / multiplier) {
                                userCache.premiumAccumulator = intermediate / 1e27;
                            }
                        }
                    }
                }

                userCache.newOwed = baseOwed.mulDiv(userCache.premiumAccumulator, user.premiumAccumulator);
                userCache.premiumInterest = userCache.newOwed - baseOwed;
            }
        }
    }

    /// @notice Write user borrow state to storage and handle premium fee accrual
    function setUserBorrow(VaultCache memory vaultCache, UserBorrowCache memory userCache) internal {
        // Accrue premium interest to totalBorrows and calculate fee
        if (!userCache.premiumInterest.isZero()) {
            uint256 newTotalBorrows = vaultCache.totalBorrows.toUint() + userCache.premiumInterest.toUint();

            // Only update if no overflow
            if (newTotalBorrows <= MAX_SANE_DEBT_AMOUNT) {
                uint256 feeAssets = userCache.premiumInterest.toUint() * vaultCache.interestFee
                    / (uint256(CONFIG_SCALE) << INTERNAL_DEBT_PRECISION_SHIFT);

                if (feeAssets != 0) {
                    uint256 totalShares = vaultCache.totalShares.toUint();
                    uint256 newTotalAssets = vaultCache.cash.toUint() + OwedLib.toAssetsUpUint(newTotalBorrows);
                    uint256 newTotalShares = newTotalAssets * totalShares / (newTotalAssets - feeAssets);

                    if (newTotalShares <= MAX_SANE_AMOUNT) {
                        uint256 newAccumulatedFees = vaultCache.accumulatedFees.toUint() + newTotalShares - totalShares;
                        vaultStorage.accumulatedFees = vaultCache.accumulatedFees = TypesLib.toShares(newAccumulatedFees);
                        vaultStorage.totalShares = vaultCache.totalShares = TypesLib.toShares(newTotalShares);
                    }
                }

                vaultStorage.totalBorrows = vaultCache.totalBorrows = TypesLib.toOwed(newTotalBorrows);
            }
        }

        // Update user storage
        UserStorage storage user = vaultStorage.users[userCache.account];
        user.setOwed(userCache.newOwed);
        user.interestAccumulator = vaultCache.interestAccumulator;
        user.premiumAccumulator = userCache.premiumAccumulator;
        user.premiumLastUpdate = uint48(block.timestamp);

        if (!userCache.newOwed.isZero()) {
            address[] memory collaterals = getCollaterals(userCache.account);
            user.designatedCollateral = collaterals.length > 0 ? collaterals[0] : address(0);
        }
    }

    function increaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal virtual {
        UserBorrowCache memory userCache = loadUserBorrow(vaultCache, account);

        Owed amount = assets.toOwed();
        userCache.newOwed = userCache.newOwed + amount;

        setUserBorrow(vaultCache, userCache);
        vaultStorage.totalBorrows = vaultCache.totalBorrows = vaultCache.totalBorrows + amount;

        logBorrow(account, assets, userCache.prevOwed.toAssetsUp(), userCache.newOwed.toAssetsUp());
    }

    /// @dev Contrary to `increaseBorrow` and `transferBorrow` this function does the accounting in Assets
    /// by first rounding up the user's debt. The rounding is an additional cost to the user and is recorded
    /// both in user's account and in `totalBorrows`
    function decreaseBorrow(VaultCache memory vaultCache, address account, Assets assets) internal virtual {
        UserBorrowCache memory userCache = loadUserBorrow(vaultCache, account);
        Owed owedExact = userCache.newOwed;
        Assets owed = owedExact.toAssetsUp();

        if (assets > owed) revert E_RepayTooMuch();

        userCache.newOwed = owed.subUnchecked(assets).toOwed();

        setUserBorrow(vaultCache, userCache);
        vaultStorage.totalBorrows = vaultCache.totalBorrows = vaultCache.totalBorrows > owedExact
            ? vaultCache.totalBorrows.subUnchecked(owedExact).addUnchecked(userCache.newOwed)
            : userCache.newOwed;

        logRepay(account, assets, userCache.prevOwed.toAssetsUp(), userCache.newOwed.toAssetsUp());
    }

    function transferBorrow(VaultCache memory vaultCache, address from, address to, Assets assets) internal virtual {
        Owed amount = assets.toOwed();

        UserBorrowCache memory fromUserCache = loadUserBorrow(vaultCache, from);

        // If amount was rounded up, or dust is left over, transfer exact amount owed
        if (
            (amount > fromUserCache.newOwed && amount.subUnchecked(fromUserCache.newOwed).isDust())
                || (amount < fromUserCache.newOwed && fromUserCache.newOwed.subUnchecked(amount).isDust())
        ) {
            amount = fromUserCache.newOwed;
        }

        if (amount > fromUserCache.newOwed) revert E_InsufficientDebt();

        fromUserCache.newOwed = fromUserCache.newOwed.subUnchecked(amount);
        setUserBorrow(vaultCache, fromUserCache);

        UserBorrowCache memory toUserCache = loadUserBorrow(vaultCache, to);

        toUserCache.newOwed = toUserCache.newOwed + amount;
        setUserBorrow(vaultCache, toUserCache);

        // with small fractional debt amounts the interest calculation could be negative in `logRepay`
        Assets fromPrevAssets = fromUserCache.prevOwed.toAssetsUp();
        Assets fromAssets = fromUserCache.newOwed.toAssetsUp();
        Assets repayAssets = fromPrevAssets > assets + fromAssets ? fromPrevAssets.subUnchecked(fromAssets) : assets;
        logRepay(from, repayAssets, fromPrevAssets, fromAssets);

        // with small fractional debt amounts the interest calculation could be negative in `logBorrow`
        Assets toPrevAssets = toUserCache.prevOwed.toAssetsUp();
        Assets toAssets = toUserCache.newOwed.toAssetsUp();
        Assets borrowAssets = assets + toPrevAssets > toAssets ? toAssets.subUnchecked(toPrevAssets) : assets;
        logBorrow(to, borrowAssets, toPrevAssets, toAssets);
    }

    function computeInterestRate(VaultCache memory vaultCache) internal virtual returns (uint256) {
        // single sload
        address irm = vaultStorage.interestRateModel;
        uint256 newInterestRate = vaultStorage.interestRate;

        if (irm != address(0)) {
            (bool success, bytes memory data) = irm.call(
                abi.encodeCall(
                    IIRM.computeInterestRate,
                    (address(this), vaultCache.cash.toUint(), vaultCache.totalBorrows.toAssetsUp().toUint())
                )
            );

            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint256));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
                vaultStorage.interestRate = uint72(newInterestRate);
            }
        }

        return newInterestRate;
    }

    function computeInterestRateView(VaultCache memory vaultCache) internal view virtual returns (uint256) {
        // single sload
        address irm = vaultStorage.interestRateModel;
        uint256 newInterestRate = vaultStorage.interestRate;

        if (irm != address(0) && isVaultStatusCheckDeferred()) {
            (bool success, bytes memory data) = irm.staticcall(
                abi.encodeCall(
                    IIRM.computeInterestRateView,
                    (address(this), vaultCache.cash.toUint(), vaultCache.totalBorrows.toAssetsUp().toUint())
                )
            );

            if (success && data.length >= 32) {
                newInterestRate = abi.decode(data, (uint256));
                if (newInterestRate > MAX_ALLOWED_INTEREST_RATE) newInterestRate = MAX_ALLOWED_INTEREST_RATE;
            }
        }

        return newInterestRate;
    }

    function calculateDTokenAddress() internal view virtual returns (address dToken) {
        // inspired by:
        // https://github.com/Vectorized/solady/blob/229c18cfcdcd474f95c30ad31b0f7d428ee8a31a/src/utils/CREATE3.sol#L82-L90
        assembly ("memory-safe") {
            mstore(0x14, address())
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ address(this) ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            // Nonce of the contract when DToken was deployed (1).
            mstore8(0x34, 0x01)

            dToken := keccak256(0x1e, 0x17)
        }
    }

    function logBorrow(address account, Assets amount, Assets prevOwed, Assets owed) private {
        Assets interest = owed.subUnchecked(prevOwed).subUnchecked(amount);
        if (!interest.isZero()) emit InterestAccrued(account, interest.toUint());
        if (!amount.isZero()) emit Borrow(account, amount.toUint());
        logDToken(account, prevOwed, owed);
    }

    function logRepay(address account, Assets amount, Assets prevOwed, Assets owed) private {
        Assets interest = owed.addUnchecked(amount).subUnchecked(prevOwed);
        if (!interest.isZero()) emit InterestAccrued(account, interest.toUint());
        if (!amount.isZero()) emit Repay(account, amount.toUint());
        logDToken(account, prevOwed, owed);
    }

    function logDToken(address account, Assets prevOwed, Assets owed) private {
        address dTokenAddress = calculateDTokenAddress();

        if (owed > prevOwed) {
            uint256 change = owed.subUnchecked(prevOwed).toUint();
            DToken(dTokenAddress).emitTransfer(address(0), account, change);
        } else if (prevOwed > owed) {
            uint256 change = prevOwed.subUnchecked(owed).toUint();
            DToken(dTokenAddress).emitTransfer(account, address(0), change);
        }
    }
}

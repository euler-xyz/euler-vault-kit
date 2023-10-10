// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Storage} from "./Storage.sol";
import {Constants} from "./Constants.sol";
import {Errors} from "./Errors.sol";
import {Events} from "./Events.sol";
import {CVCClient} from "./CVCClient.sol";
import {IERC20} from "../IEVault.sol";
import {RPow} from "../lib/RPow.sol";
import {Utils} from "../lib/Utils.sol";

import {console2} from "forge-std/Test.sol"; // DEV_MODE



contract BaseModule is Storage, Constants, Errors, Events, CVCClient {
    address immutable public factory;

    modifier FREEMEM() {
        uint origFreeMemPtr;

        assembly {
            origFreeMemPtr := mload(0x40)
        }

        _;

        /*
        assembly { // DEV_MODE: overwrite the freed memory with garbage to detect bugs
            let garbage := 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF
            for { let i := origFreeMemPtr } lt(i, mload(0x40)) { i := add(i, 32) } { mstore(i, garbage) }
        }
        */

        assembly {
            mstore(0x40, origFreeMemPtr)
        }
    }

    modifier nonReentrantWithChecks() { _; }

    // modifier nonReentrant() {
    // if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

    //     marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
    //     _;
    //     marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    // }

    modifier lock(address account, MarketCache memory marketCache, uint8 pauseType) {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        marketStorage.reentrancyLock = REENTRANCYLOCK__LOCKED;
        // marketSnapshot(pauseType, marketCache); 

        _;

        marketStorage.reentrancyLock = REENTRANCYLOCK__UNLOCKED;

        // checkAccountAndMarketStatus(account);
        // logMarketStatus(marketCache);
    }

    constructor(address factory_, address cvc_) CVCClient(cvc_) {
        factory = factory_;
    }

    function proxyMetadata() internal pure returns (address marketAsset, address riskManager) {
        assembly {
            marketAsset := shr(96, calldataload(sub(calldatasize(), 40)))
            riskManager := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    // MarketCache

    struct MarketCache {
        address asset;
        address riskManager;

        uint112 totalBalances;
        uint144 totalBorrows;

        uint96 feesBalance;

        uint interestAccumulator;

        uint40 lastInterestAccumulatorUpdate;
        int96 interestRate;
        uint16 interestFee;

        uint poolSize; // result of calling balanceOf on asset (in external units)
    }

    function initMarketCache(MarketCache memory marketCache) internal view returns (bool dirty) {
        dirty = false;

        // Proxy metadata

        (address asset, address riskManager) = proxyMetadata();
        marketCache.asset = asset;
        marketCache.riskManager = riskManager;

        // Storage loads

        marketCache.lastInterestAccumulatorUpdate = marketStorage.lastInterestAccumulatorUpdate;
        marketCache.feesBalance = marketStorage.feesBalance;
        marketCache.interestRate = marketStorage.interestRate;
        marketCache.interestFee = marketStorage.interestFee;

        marketCache.totalBalances = marketStorage.totalBalances;
        marketCache.totalBorrows = marketStorage.totalBorrows;

        marketCache.interestAccumulator = marketStorage.interestAccumulator;

        // Derived state

        uint poolSize = callBalanceOf(marketCache, address(this));
        marketCache.poolSize = poolSize <= MAX_SANE_AMOUNT ? poolSize : 0;

        // Update interest  accumulator and fees balance 

        if (block.timestamp != marketCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            uint deltaT = block.timestamp - marketCache.lastInterestAccumulatorUpdate;

            // Compute new values

            uint newInterestAccumulator = (RPow.rpow(uint(int(marketCache.interestRate) + 1e27), deltaT, 1e27) * marketCache.interestAccumulator) / 1e27;

            uint newTotalBorrows = marketCache.totalBorrows * newInterestAccumulator / marketCache.interestAccumulator;

            uint newFeesBalance = marketCache.feesBalance;
            uint newTotalBalances = marketCache.totalBalances;

            uint feeAmount = (newTotalBorrows - marketCache.totalBorrows)
                               * marketCache.interestFee
                               / (INTEREST_FEE_SCALE * INTERNAL_DEBT_PRECISION);

            if (feeAmount != 0) {
                uint poolAssets = marketCache.poolSize + (newTotalBorrows / INTERNAL_DEBT_PRECISION);
                newTotalBalances = poolAssets * newTotalBalances / (poolAssets - feeAmount);
                newFeesBalance += newTotalBalances - marketCache.totalBalances;
            }

            // Store new values in marketCache, only if no overflows will occur

            if (newTotalBalances <= MAX_SANE_AMOUNT && newTotalBorrows <= MAX_SANE_DEBT_AMOUNT && newFeesBalance <= MAX_SANE_SMALL_AMOUNT) {
                marketCache.totalBorrows = encodeDebtAmount(newTotalBorrows);
                marketCache.interestAccumulator = newInterestAccumulator;
                marketCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalBalances != marketCache.totalBalances) {
                    marketCache.feesBalance = encodeSmallAmount(newFeesBalance);
                    marketCache.totalBalances = encodeAmount(newTotalBalances);
                }
            }
        }
    }

    function loadMarketCache() internal returns (MarketCache memory marketCache) {
        if (initMarketCache(marketCache)) {
            marketStorage.lastInterestAccumulatorUpdate = marketCache.lastInterestAccumulatorUpdate;
            marketStorage.feesBalance = marketCache.feesBalance;

            marketStorage.totalBalances = marketCache.totalBalances;
            marketStorage.totalBorrows = marketCache.totalBorrows;

            marketStorage.interestAccumulator = marketCache.interestAccumulator;

        }
    }

    // function loadMarketCacheRO() internal view returns (MarketCache memory marketCache) {
    //     if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();
    //     initMarketCache(marketCache);
    // }

    // function internalloadMarketCacheRO() internal view returns (MarketCache memory marketCache) {
    //     initMarketCache(marketCache);
    // }



    // Utils

    function validateExternalAmount(uint externalAmount) internal pure returns (uint) {
        if (externalAmount > MAX_SANE_AMOUNT) revert E_AmountTooLarge();
        return externalAmount;
    }

    function encodeAmount(uint amount) internal pure returns (uint112) {
        if (amount > MAX_SANE_AMOUNT) revert E_AmountTooLargeToEncode();
        return uint112(amount);
    }

    function encodeSmallAmount(uint amount) internal pure returns (uint96) {
        if (amount > MAX_SANE_SMALL_AMOUNT) revert E_SmallAmountTooLargeToEncode();
        return uint96(amount);
    }

    function encodeDebtAmount(uint amount) internal pure returns (uint144) {
        if (amount > MAX_SANE_DEBT_AMOUNT) revert E_DebtAmountTooLargeToEncode();
        return uint144(amount);
    }

    function totalsVirtual(MarketCache memory marketCache) private pure returns (uint totalAssets, uint totalBalances) {
        // adding 1 wei virtual asset and share. See https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack
        totalAssets = marketCache.poolSize + (marketCache.totalBorrows / INTERNAL_DEBT_PRECISION) + 1;
        totalBalances = marketCache.totalBalances + 1;
    }

    function assetsToShares(MarketCache memory marketCache, uint amount) internal pure returns (uint) {
        validateExternalAmount(amount);
        (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
        return amount * totalBalances / totalAssets;
    }

    // function assetsToSharesRoundUp(MarketCache memory marketCache, uint amount) internal view returns (uint) {
    //     validateExternalAmount(amount);
    //     (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
    //     return (amount * totalBalances / totalAssets) + (mulmod(amount, totalBalances, totalAssets) != 0 ? 1 : 0);
    // }

    // function sharesToAssets(MarketCache memory marketCache, uint amount) internal view returns (uint) {
    //     validateExternalAmount(amount);
    //     (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
    //     return amount * totalAssets / totalBalances;
    // }

    // function sharesToAssetsRoundUp(MarketCache memory marketCache, uint amount) internal view returns (uint) {
    //     validateExternalAmount(amount);
    //     (uint totalAssets, uint totalBalances) = totalsVirtual(marketCache);
    //     return (amount * totalAssets / totalBalances) + (mulmod(amount, totalAssets, totalBalances) != 0 ? 1 : 0);
    // }

    function callBalanceOf(MarketCache memory marketCache, address account) internal view FREEMEM returns (uint) {
        // We set a gas limit so that a malicious token can't eat up all gas and cause a liquidity check to fail.

        (bool success, bytes memory data) = marketCache.asset.staticcall{gas: 200000}(abi.encodeWithSelector(IERC20.balanceOf.selector, account));

        // If token's balanceOf() call fails for any reason, return 0. This prevents malicious tokens from causing liquidity checks to fail.
        // If the contract doesn't exist (maybe because selfdestructed), then data.length will be 0 and we will return 0.
        // Data length > 32 is allowed because some legitimate tokens append extra data that can be safely ignored.

        if (!success || data.length < 32) return 0;

        return abi.decode(data, (uint256));
    }

    // function updateInterestParams(MarketCache memory marketCache) internal {
    //     uint32 utilisation;

    //     uint totalBorrows = marketCache.totalBorrows / INTERNAL_DEBT_PRECISION;
    //     uint poolAssets = marketCache.poolSize + totalBorrows;
    //     if (poolAssets == 0) utilisation = 0; // empty pool arbitrarily given utilisation of 0
    //     else utilisation = uint32(totalBorrows * (uint(type(uint32).max) * 1e18) / poolAssets / 1e18);

    //     (int96 newInterestRate, uint16 newInterestFee) = IRiskManager(marketCache.riskManager).computeInterestParams(marketCache.asset, utilisation);
    //     if (newInterestFee != marketCache.interestFee) {
    //         if (newInterestFee > INTEREST_FEE_SCALE) {
    //             //revert E_BadInterestFee();
    //             //ignore incorrect value
    //             newInterestFee = marketCache.interestFee;
    //         } else {
    //             emit NewInterestFee(newInterestFee);
    //         }
    //     }
    //     marketStorage.interestRate = marketCache.interestRate = newInterestRate;
    //     marketStorage.interestFee = marketCache.interestFee = newInterestFee;
    // }

    // function logMarketStatus(MarketCache memory a) internal {
    //     emit MarketStatus(address(this), a.totalBalances, a.totalBorrows / INTERNAL_DEBT_PRECISION, a.feesBalance, a.poolSize, a.interestAccumulator, a.interestRate, block.timestamp);
    // }

    // // Balances

    function increaseBalance(MarketCache memory marketCache, address account, uint amount) internal {
        marketStorage.users[account].balance = encodeAmount(marketStorage.users[account].balance + amount);

        marketStorage.totalBalances = marketCache.totalBalances = encodeAmount(uint(marketCache.totalBalances) + amount);

        emit IncreaseBalance(address(this), account, amount);
        emit Transfer(address(0), account, amount);
    }

    // function decreaseBalance(MarketCache memory marketCache, address account, uint amount) internal {
    //     uint origBalance = marketStorage.users[account].balance;
    //     if (origBalance < amount) revert E_InsufficientBalance();
    //     marketStorage.users[account].balance = encodeAmount(origBalance - amount);

    //     marketStorage.totalBalances = marketCache.totalBalances = encodeAmount(marketCache.totalBalances - amount);

    //     emit DecreaseBalance(address(this), account, amount);
    //     emit Transfer(account, address(0), amount);
    // }

    // function transferBalance(address from, address to, uint amount) internal {
    //     uint origFromBalance = marketStorage.users[from].balance;
    //     if (origFromBalance < amount) revert E_InsufficientBalance();
    //     uint newFromBalance;
    //     unchecked { newFromBalance = origFromBalance - amount; }

    //     marketStorage.users[from].balance = encodeAmount(newFromBalance);
    //     marketStorage.users[to].balance = encodeAmount(marketStorage.users[to].balance + amount);

    //     emit DecreaseBalance(address(this), from, amount);
    //     emit IncreaseBalance(address(this), to, amount);
    //     emit Transfer(from, to, amount);
    // }

    // function withdrawAmounts(MarketCache memory marketCache, address account, uint assets) internal view returns (uint, uint) {
    //     uint shares;
    //     if (assets == type(uint).max) {
    //         shares = marketStorage.users[account].balance;
    //         assets = sharesToAssets(marketCache, shares);
    //     } else {
    //         // shares = assetsToSharesRoundUp(marketCache, validateExternalAmount(assets));
    //         shares = assetsToSharesRoundUp(marketCache, assets);
    //     }

    //     return (assets, shares);
    // }

    // // Allowance

    // function decreaseAllowance(address from, address to, uint amount) internal {
    //     uint allowanceCache = marketStorage.eVaultAllowance[from][to];
    //     if (from != to && allowanceCache != type(uint).max) {
    //         if (allowanceCache < amount) revert E_InsufficientAllowance();
    //         unchecked { allowanceCache -= amount; }
    //         marketStorage.eVaultAllowance[from][to] = allowanceCache;
    //         emit Approval(from, to, allowanceCache);
    //     }
    // }

    // // Borrows

    // // Returns internal precision

    // function getCurrentOwedExact(MarketCache memory marketCache, address account, uint owed) internal view returns (uint) {
    //     // Don't bother loading the user's accumulator
    //     if (owed == 0) return 0;

    //     // Can't divide by 0 here: If owed is non-zero, we must've initialised the user's interestAccumulator
    //     return owed * marketCache.interestAccumulator / marketStorage.users[account].interestAccumulator;
    // }

    // // When non-zero, we round *up* to the smallest external unit so that outstanding dust in a loan can be repaid.
    // // unchecked is OK here since owed is always loaded from storage, so we know it fits into a uint144 (pre-interest accural)
    // // Takes internal debt precision (assets scaled up by 1e9), returns amount in assets.

    // function owedToAssetsRoundUp(uint owed) private pure returns (uint) {
    //     if (owed == 0) return 0;

    //     unchecked {
    //         return (owed + INTERNAL_DEBT_PRECISION - 1) / INTERNAL_DEBT_PRECISION;
    //     }
    // }

    // // Returns debt in assets precision, rounded up

    // function getCurrentOwed(MarketCache memory marketCache, address account) internal view returns (uint) {
    //     return owedToAssetsRoundUp(getCurrentOwedExact(marketCache, account, marketStorage.users[account].owed));
    // }

    // function updateUserBorrow(MarketCache memory marketCache, address account) private returns (uint newOwedExact, uint prevOwedExact) {
    //     prevOwedExact = marketStorage.users[account].owed;

    //     newOwedExact = getCurrentOwedExact(marketCache, account, prevOwedExact);

    //     marketStorage.users[account].owed = encodeDebtAmount(newOwedExact);
    //     marketStorage.users[account].interestAccumulator = marketCache.interestAccumulator;
    // }

    // function calculateDTokenAddress() internal view returns (address dToken) {
    //     // inspired by https://github.com/Vectorized/solady/blob/229c18cfcdcd474f95c30ad31b0f7d428ee8a31a/src/utils/CREATE3.sol#L82-L90
    //     assembly ("memory-safe") {
    //         mstore(0x14, address())
    //         // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ address(this) ++ 0x01).
    //         // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
    //         mstore(0x00, 0xd694)
    //         // Nonce of the contract when DToken was deployed (1).
    //         mstore8(0x34, 0x01)

    //         dToken := keccak256(0x1e, 0x17)
    //     }
    // }

    // function logBorrowChange(address account, uint prevOwed, uint owed) private {
    //     prevOwed = owedToAssetsRoundUp(prevOwed);
    //     owed = owedToAssetsRoundUp(owed);

    //     address dTokenAddress = calculateDTokenAddress();

    //     if (owed > prevOwed) {
    //         uint change = owed - prevOwed;
    //         emit Borrow(address(this), account, change);
    //         DToken(dTokenAddress).emitTransfer(address(0), account, change);
    //     } else if (prevOwed > owed) {
    //         uint change = prevOwed - owed;
    //         emit Repay(address(this), account, change);
    //         DToken(dTokenAddress).emitTransfer(account, address(0), change);
    //     }
    // }

    // function increaseBorrow(MarketCache memory marketCache, address account, uint amount) internal {
    //     amount *= INTERNAL_DEBT_PRECISION;

    //     (uint owed, uint prevOwed) = updateUserBorrow(marketCache, account);

    //     owed += amount;

    //     marketStorage.users[account].owed = encodeDebtAmount(owed);
    //     marketStorage.totalBorrows = marketCache.totalBorrows = encodeDebtAmount(marketCache.totalBorrows + amount);

    //     logBorrowChange(account, prevOwed, owed);
    // }

    // function decreaseBorrow(MarketCache memory marketCache, address account, uint assets) internal {
    //     (uint owed, uint prevOwed) = updateUserBorrow(marketCache, account);
    //     uint owedAssets = owedToAssetsRoundUp(owed);

    //     if (assets > owedAssets) revert E_RepayTooMuch();
    //     uint owedRemaining;
    //     unchecked { owedRemaining = owedAssets - assets; }

    //     if (owed > marketCache.totalBorrows) owed = marketCache.totalBorrows;

    //     if (owedRemaining == 0) releaseControllerInternal(account);

    //     owedRemaining *= INTERNAL_DEBT_PRECISION;

    //     marketStorage.users[account].owed = encodeDebtAmount(owedRemaining);
    //     marketStorage.totalBorrows = marketCache.totalBorrows = encodeDebtAmount(marketCache.totalBorrows - owed + owedRemaining);

    //     logBorrowChange(account, prevOwed, owedRemaining);
    // }

    // function transferBorrow(MarketCache memory marketCache, address from, address to, uint debtAssets) internal {
    //     uint debtAmount = debtAssets * INTERNAL_DEBT_PRECISION;

    //     (uint fromOwed, uint fromOwedPrev) = updateUserBorrow(marketCache, from);
    //     (uint toOwed, uint toOwedPrev) = updateUserBorrow(marketCache, to);

    //     // If amount was rounded up, transfer exact amount owed
    //     if (debtAmount > fromOwed && debtAmount - fromOwed < INTERNAL_DEBT_PRECISION) debtAmount = fromOwed;

    //     if (fromOwed < debtAmount) revert E_InsufficientBalance();
    //     unchecked { fromOwed -= debtAmount; }

    //     // Transfer any residual dust
    //     if (fromOwed < INTERNAL_DEBT_PRECISION) {
    //         debtAmount += fromOwed;
    //         fromOwed = 0;
    //     }

    //     toOwed += debtAmount;

    //     marketStorage.users[from].owed = encodeDebtAmount(fromOwed);
    //     marketStorage.users[to].owed = encodeDebtAmount(toOwed);

    //     if (fromOwedPrev > 0 && fromOwed == 0) releaseControllerInternal(from);

    //     logBorrowChange(from, fromOwedPrev, fromOwed);
    //     logBorrowChange(to, toOwedPrev, toOwed);
    // }



    // // Fees

    // function increaseFees(MarketCache memory marketCache, uint amount) internal {
    //     uint newFeesBalance = marketCache.feesBalance + amount;
    //     uint newTotalBalances = marketCache.totalBalances + amount;

    //     if (newFeesBalance <= MAX_SANE_SMALL_AMOUNT && newTotalBalances <= MAX_SANE_AMOUNT) {
    //         marketStorage.feesBalance = marketCache.feesBalance = encodeSmallAmount(newFeesBalance);
    //         marketStorage.totalBalances = marketCache.totalBalances = encodeAmount(newTotalBalances);
    //     }
    // }



    // Token asset transfers

    function pullTokens(MarketCache memory marketCache, address from, uint amount) internal returns (uint amountTransferred) {
        uint poolSizeBefore = marketCache.poolSize;

        Utils.safeTransferFrom(marketCache.asset, from, address(this), amount);
        uint poolSizeAfter = marketCache.poolSize = validateExternalAmount(callBalanceOf(marketCache, address(this)));

        if (poolSizeAfter < poolSizeBefore) revert E_NegativeTransferAmount();
        unchecked { amountTransferred = poolSizeAfter - poolSizeBefore; }
    }

    // function pushTokens(MarketCache memory marketCache, address to, uint amount) internal returns (uint amountTransferred) {
    //     uint poolSizeBefore = marketCache.poolSize;

    //     Utils.safeTransfer(marketCache.asset, to, amount);
    //     uint poolSizeAfter = marketCache.poolSize = validateExternalAmount(callBalanceOf(marketCache, address(this)));

    //     if (poolSizeBefore < poolSizeAfter) revert E_NegativeTransferAmount();
    //     unchecked { amountTransferred = poolSizeBefore - poolSizeAfter; }
    // }

    // // TODO revisit
    // function getLiquidityPayload(address account, address[] memory collateralMarkets) internal view returns (address riskManager, IRiskManager.MarketAssets memory liability, IRiskManager.MarketAssets[] memory collaterals) {
    //     liability.market = address(this);

    //     MarketCache memory marketCache = internalloadMarketCacheRO();

    //     riskManager = marketCache.riskManager;

    //     liability.assets = getCurrentOwed(marketCache, account);
    //     liability.assetsSet = true;

    //     collaterals = new IRiskManager.MarketAssets[](collateralMarkets.length);

    //     for (uint i = 0; i < collateralMarkets.length;) {
    //         address market = collateralMarkets[i];
    //         collaterals[i].market = market;
    //         if (market == address(this)) {
    //             collaterals[i].assets = sharesToAssets(marketCache, marketStorage.users[account].balance);
    //             collaterals[i].assetsSet = true;
    //         }

    //         unchecked { ++i; }
    //     }
    // }

    // function getMarketSnapshot(uint8 operationType, MarketCache memory marketCache) internal view returns (MarketSnapshot memory) {
    //     return MarketSnapshot({
    //         performedOperations: operationType,
    //         poolSize: encodeAmount(marketCache.poolSize),
    //         totalBalances: encodeAmount(sharesToAssets(marketCache, marketCache.totalBalances)),
    //         totalBorrows: encodeAmount(marketCache.totalBorrows / INTERNAL_DEBT_PRECISION),
    //         interestAccumulator: uint144(marketCache.interestAccumulator)
    //     });
    // }

    // function marketSnapshot(uint8 operationType, MarketCache memory marketCache) internal {
    //     uint8 performedOperations = marketStorage.marketSnapshot.performedOperations;

    //     if (performedOperations == 0) {
    //         marketStorage.marketSnapshot = getMarketSnapshot(operationType, marketCache);
    //     } else {
    //         marketStorage.marketSnapshot.performedOperations = performedOperations | operationType;
    //     }
    // }
}

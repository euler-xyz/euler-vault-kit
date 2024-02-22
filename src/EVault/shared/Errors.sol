// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

contract Errors {
    error E_Initialized();
    error E_ProxyMetadata();
    error E_SelfApproval();
    error E_SelfTransfer();
    error E_InsufficientAllowance();
    error E_UnauthorizedDebtTransfer();
    error E_TransferAmountMismatch();
    error E_InsufficientPoolSize();
    error E_FlashLoanNotRepaid();
    error E_Reentrancy();
    error E_OperationPaused();
    error E_OutstandingDebt();
    error E_InsufficientBalance();
    error E_CreateProxyInvalidModule();
    error E_CreateProxyInternalModule();
    error E_InvalidProxy();
    error E_LogProxyFail();
    error E_AmountTooLarge();
    error E_AmountTooLargeToEncode();
    error E_SmallAmountTooLargeToEncode();
    error E_DebtAmountTooLargeToEncode();
    error E_RepayTooMuch();
    error E_NegativeTransferAmount();
    error E_TransientState();
    error E_InputTooShort();
    error E_UnrecognizedEVaultCaller();
    error E_UnrecognizedDTokenCaller();
    error E_MarketNotActivated();
    error E_SelfLiquidation();
    error E_ControllerDisabled();
    error E_CollateralDisabled();
    error E_InvalidLiability();
    error E_ViolatorLiquidityDeferred();
    error E_ExcessiveRepayAmount();
    error E_MinYield();
    error E_InvalidToken();
    error E_InvalidDToken();
    error E_InvalidMarket();
    error E_InvalidLiquidationState();
    error E_BadAddress();
    error E_ZeroAssets();
    error E_ZeroShares();
    error E_Unauthorized();
    error E_BadInterestFee();
    error E_FeesDepleted();
    error E_CheckUnauthorized();
    error E_InvalidSnapshot();
    error E_InterestAccumulatorInvariant();
    error E_AccountCheckType();
    error E_BalancesInvariant();
    error E_BalanceForwarderUnsupported();

    error E_NotSupported();
    error E_EmptyError();
    error E_InterestFeeInit();
    error E_VaultStatusCheckDeferred();

    // FIXME: normalise these to E_ namespace

    error RM_Unauthorized();
    error RM_AccountLiquidity();
    error RM_MarketActivated();
    error RM_InvalidUnderlying();

    error RM_NoLiability();
    error RM_NotController();
    error RM_EmptyError();
    error RM_ExcessiveRepay();
    error RM_ExcessiveYield();
    error RM_InsufficientBalance();
    error RM_BadFee();
    error RM_ExcessiveRepayAmount();
    error RM_TransientState();
    error RM_InvalidAmountCap();
    error RM_SupplyCapExceeded();
    error RM_BorrowCapExceeded();
    error RM_InvalidLiquidationState();
    error RM_InvalidLTVAsset();
}

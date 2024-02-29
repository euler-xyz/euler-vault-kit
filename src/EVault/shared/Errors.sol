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
    error E_OperationDisabled();
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
    error E_BadBorrowCap();
    error E_BadSupplyCap();
    error E_BadCollateral();

    error E_AccountLiquidity();
    error E_NoLiability();
    error E_NotController();
    error E_BadFee();
    error E_InvalidAmountCap();
    error E_SupplyCapExceeded();
    error E_BorrowCapExceeded();
    error E_InvalidLTVAsset();
    error E_InvalidLTV();
    error E_NoPriceOracle();

    error E_ExpiredSignature();
    error E_InvalidSignatureS();
    error E_InvalidSignature();
    error E_InvalidSigner();
}

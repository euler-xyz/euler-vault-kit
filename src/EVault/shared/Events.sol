// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {LTVConfig} from "./types/LTVConfig.sol";

abstract contract Events {
    event EVaultCreated(address indexed creator, address indexed asset, address dToken);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event Borrow(address indexed account, uint256 assets);
    event Repay(address indexed account, uint256 assets);

    event DebtSocialized(address indexed account, uint256 assets);

    event ConvertFees(
        address indexed sender,
        address indexed protocolReceiver,
        address indexed feeReceiver,
        uint256 protocolAssets,
        uint256 feeAssets
    );

    event MarketStatus(
        uint256 totalShares,
        uint256 totalBorrows,
        uint256 feesBalance,
        uint256 poolSize,
        uint256 interestAccumulator,
        uint72 interestRate,
        uint256 timestamp
    );
    event Liquidate(
        address indexed liquidator,
        address indexed violator,
        address collateral,
        uint256 repayAssets,
        uint256 yieldBalance
    );
    event DisableController(address indexed account);

    event SkimAssets(address indexed admin, address indexed receiver, uint256 assets);

    event BalanceForwarderStatus(address indexed account, bool status);

    event GovSetName(string newName);
    event GovSetSymbol(string newSymbol);
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetFeeReceiver(address indexed newFeeReceiver);
    event GovSetLTV(address indexed collateral, uint40 targetTimestamp, uint16 targetLTV, uint24 rampDuration, uint16 originalLTV);
    event GovSetIRM(address interestRateModel, bytes resetParams);
    event GovSetOracle(address oracle);
    event GovSetMarketPolicy(uint32 newDisabledOps, uint16 newSupplyCap, uint16 newBorrowCap);
    event GovSetInterestFee(uint16 newFee);
    event GovSetDebtSocialization(bool debtSocialization);
    event GovSetUnitOfAccount(address newUnitOfAccount);
}

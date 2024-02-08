// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

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
        uint96 feesBalance,
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
}

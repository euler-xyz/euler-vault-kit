// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

abstract contract Events {
    event EVaultCreated(address indexed creator, address indexed asset, address indexed riskManager, address dToken);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event Borrow(address indexed account, uint256 assets);
    event Repay(address indexed account, uint256 assets);

    event RequestTransfer(address indexed from, address indexed to, uint256 amount);
    event RequestDeposit(address indexed owner, address indexed receiver, uint256 assets);
    event RequestMint(address indexed owner, address indexed receiver, uint256 shares);
    event RequestWithdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets);
    event RequestRedeem(address indexed sender, address indexed receiver, address indexed owner, uint256 shares);
    event RequestBorrow(address indexed account, address indexed receiver, uint256 amount);
    event RequestRepay(address indexed sender, address indexed receiver, uint256 amount);
    event RequestWind(address indexed account, address indexed collateralReceiver, uint256 assets);
    event RequestUnwind(address indexed account, address indexed debtFrom, uint256 assets);
    event RequestPullDebt(address indexed from, address indexed to, uint256 amount);

    event RequestLiquidate(
        address indexed liquidator, address indexed violator, address collateral, uint256 repay, uint256 minYield
    );
    event RequestConvertFees(address indexed account);

    event NewInterestFee(uint16 newFee);
    event NewProtocolFeesHolder(address protocolFeesHolder);
    event ConvertFees(
        address indexed protocolFeesHolder,
        address indexed feeRecipient,
        uint256 protocolAssets,
        uint256 riskManagerAssets
    );

    event MarketStatus(
        uint256 totalBalances,
        uint256 totalBorrows,
        uint96 feesBalance,
        uint256 poolSize,
        uint256 interestAccumulator,
        int96 interestRate,
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
}

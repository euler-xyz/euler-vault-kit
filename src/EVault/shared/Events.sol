// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

abstract contract Events {

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Deposit(address indexed sender, address indexed owner, uint assets, uint shares);
    event Withdraw( address indexed sender, address indexed receiver, address indexed owner, uint assets, uint shares);

    event DTokenCreated(address indexed dToken);

    event IncreaseBalance(address indexed market, address indexed account, uint amount);
    event DecreaseBalance(address indexed market, address indexed account, uint amount);
    event Borrow(address indexed market, address indexed account, uint amount);
    event Repay(address indexed market, address indexed account, uint amount);

    event Liquidate(address indexed liquidator, address indexed violator, address indexed asset, address collateral, uint repayAssets, uint yieldBalance, uint feeAssets);

    event MarketStatus(address indexed market, uint totalBalances, uint totalBorrows, uint96 feesBalance, uint poolSize, uint interestAccumulator, int96 interestRate, uint timestamp);

    event ReleaseController(address indexed account, address indexed market);

    event RequestTransferEVault(address indexed from, address indexed to, uint amount);

    event RequestDeposit(address indexed owner, address indexed receiver, uint assets);
    event RequestMint(address indexed owner, address indexed receiver, uint shares);
    event RequestWithdraw(address indexed sender, address indexed receiver, address indexed owner, uint assets);
    event RequestRedeem(address indexed sender, address indexed receiver, address indexed owner, uint shares);

    event RequestBorrow(address indexed account, address indexed receiver, uint amount);
    event RequestRepay(address indexed sender, address indexed receiver, uint amount);
    event RequestWind(address indexed account, address indexed collateralReceiver, uint assets);
    event RequestUnwind(address indexed account, address indexed debtFrom, uint assets);
    event RequestPullDebt(address indexed from, address indexed to, uint amount);
    event RequestDonate(address indexed account, uint amount);

    event RequestLiquidate(address indexed liquidator, address indexed violator, address indexed asset, address collateral, uint repay, uint minYield);

    event RequestConvertFees(address indexed account);

    event NewInterestFee(uint16 newFee);
    event ConvertFees(address indexed protocolFeesHolder, address indexed riskManager, uint protocolAssets, uint riskManagerAssets);
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault, IERC20} from "../EVault/IEVault.sol";

contract SwapValidator  {
    error SwapValidator_skimMin();
    error SwapValidator_debtMax();

    function validateSkimMin(address vault, uint256 amountMin) external view {
        if (amountMin == 0) return;

        uint256 cash = IEVault(vault).cash();
        uint256 balance = IERC20(IEVault(vault).asset()).balanceOf(vault);

        if (balance <= cash || balance - cash < amountMin) revert SwapValidator_skimMin();
    }

    function validateDebtMax(address vault, address account, uint256 amountMax) external view {
        uint256 debt = IEVault(vault).debtOf(account);
        if (debt > amountMax) revert SwapValidator_debtMax();
    }
}

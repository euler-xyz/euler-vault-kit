// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseModule} from "../shared/BaseModule.sol";
import {IERC20} from "../IEVault.sol";

abstract contract ERC20Module is BaseModule, IERC20 {

    /// @inheritdoc IERC20
    function name() external view virtual returns(string memory) {
        return "EVault";
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view virtual returns (uint) {
        return marketStorage.users[account].balance;
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint amount) external virtual returns (bool) {}

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint amount) external virtual returns (bool) {}
}

contract ERC20 is ERC20Module {
    constructor(address factory, address cvc) BaseModule(factory, cvc) {}
}
// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IToken, IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";
import {RevertBytes} from "../shared/lib/RevertBytes.sol";

import "../shared/types/Types.sol";

abstract contract TokenModule is IToken, Base, BalanceUtils {
    using TypesLib for uint256;

    /// @inheritdoc IERC20
    function name() external view virtual reentrantOK returns (string memory) {
        // TODO name()
        return "";
    }

    /// @inheritdoc IERC20
    function symbol() external view virtual reentrantOK returns (string memory) {
        // TODO symbol()
        return "";
    }

    /// @inheritdoc IERC20
    function decimals() external view virtual reentrantOK returns (uint8) {
        (IERC20 asset_,) = ProxyUtils.metadata();

        return asset_.decimals();
    }

    /// @inheritdoc IERC20
    function totalSupply() external view virtual nonReentrantView returns (uint256) {
        return loadMarket().totalBalances.toUint();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view virtual nonReentrantView returns (uint256) {
        return marketStorage.users[account].balance.toUint();
    }

    /// @inheritdoc IERC20
    function allowance(address holder, address spender) external view virtual nonReentrantView returns (uint256) {
        return marketStorage.eVaultAllowance[holder][spender];
    }

        /// @inheritdoc IERC20
    function transfer(address to, uint256 amount) external virtual reentrantOK returns (bool) {
        return transferFrom(address(0), to, amount);
    }


    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 amount) public virtual nonReentrant returns (bool) {
        // TODO transferFrom()
        return true;
    }
}

contract Token is TokenModule {
    constructor(address evc) Base(evc) {}
}

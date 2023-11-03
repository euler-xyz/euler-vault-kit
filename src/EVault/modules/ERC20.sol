// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";

import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

abstract contract ERC20Module is IERC20, Base {

    /// @inheritdoc IERC20
    function name() external view virtual returns (string memory) {
        (IERC20 asset_,) = ProxyUtils.metadata();

        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset_).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) revertBytes(data);
        return string.concat("Euler Pool: ", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    /// @inheritdoc IERC20
    function symbol() external view virtual returns (string memory) {
        (IERC20 asset_,) = ProxyUtils.metadata();

        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset_).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) revertBytes(data);
        return string.concat("e", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    /// @inheritdoc IERC20
    function decimals() external view virtual returns (uint8) {
        (IERC20 asset_,) = ProxyUtils.metadata();

        return asset_.decimals();
    }

    /// @inheritdoc IERC20
    function totalSupply() external view virtual returns (uint) {
        return loadMarketNonReentrant().totalBalances.toUint();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view virtual returns (uint) {
        return marketStorage.users[account].balance.toUint();
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint amount) external virtual returns (bool) {}

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint amount) external virtual returns (bool) {}
}

contract ERC20 is ERC20Module {
    constructor(address factory, address cvc) Base(factory, cvc) {}
}

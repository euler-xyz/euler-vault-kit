// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IToken, IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BalanceUtils} from "../shared/BalanceUtils.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/types/Types.sol";

/// @title TokenModule
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An EVault module handling ERC20 behaviour of vault shares
abstract contract TokenModule is IToken, Base, BalanceUtils {
    using TypesLib for uint256;

    /// @inheritdoc IERC20
    function name() public view virtual reentrantOK returns (string memory) {
        return bytes(vaultStorage.name).length > 0 ? vaultStorage.name : "Unnamed Euler Vault";
    }

    /// @inheritdoc IERC20
    function symbol() public view virtual reentrantOK returns (string memory) {
        return bytes(vaultStorage.symbol).length > 0 ? vaultStorage.symbol : "UNKNOWN";
    }

    /// @inheritdoc IERC20
    function decimals() public view virtual reentrantOK returns (uint8) {
        (IERC20 asset,,) = ProxyUtils.metadata();
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeCall(IERC20.decimals, ()));
        return success && data.length >= 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual nonReentrantView returns (uint256) {
        return loadVault().totalShares.toUint();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual nonReentrantView returns (uint256) {
        return vaultStorage.users[account].getBalance().toUint();
    }

    /// @inheritdoc IERC20
    function allowance(address holder, address spender) public view virtual nonReentrantView returns (uint256) {
        return vaultStorage.users[holder].eTokenAllowance[spender];
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 amount) public virtual reentrantOK returns (bool) {
        return transferFrom(address(0), to, amount);
    }

    /// @inheritdoc IToken
    function transferFromMax(address from, address to) public virtual reentrantOK returns (bool) {
        return transferFrom(from, to, vaultStorage.users[from].getBalance().toUint());
    }

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 amount) public virtual nonReentrant returns (bool) {
        (, address account) = initOperation(OP_TRANSFER, from == address(0) ? CHECKACCOUNT_CALLER : from);

        if (from == address(0)) from = account;
        if (from == to) revert E_SelfTransfer();

        Shares shares = amount.toShares();

        decreaseAllowance(from, account, shares);
        transferBalance(from, to, shares);

        return true;
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 amount) public virtual nonReentrant returns (bool) {
        address account = EVCAuthenticate();

        setAllowance(account, spender, amount);

        return true;
    }
}

/// @dev Deployable module contract
contract Token is TokenModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20, Context} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {IEVC, EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title ERC20Collateral
/// @notice It extends the ERC20 token standard to add the EVC authentication and account status checks so that the
/// token contract can be used as collateral in the EVC ecosystem.
abstract contract ERC20Collateral is EVCUtil, ERC20Permit, ReentrancyGuard {
    constructor(IEVC _evc_, string memory _name_, string memory _symbol_) EVCUtil(_evc_) ERC20(_name_, _symbol_) ERC20Permit(_name_) {}

    /// @notice Transfers a certain amount of tokens to a recipient.
    /// @dev Overriden to add re-entrancy protection.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of tokens from a sender to a recipient.
    /// @dev Overriden to add re-entrancy protection.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override nonReentrant returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    /// @notice Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
    /// (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
    /// this function.
    /// @dev Overriden to require account status checks on transfers from non-zero addresses. The account status check
    /// must be required on any operation that reduces user's balance. Note that the user balance cannot be modified
    /// after the account status check is required. If that's the case, the contract must be modified so that the
    /// account status check is required as the very last operation of the function.
    /// @param from The address from which tokens are transferred or burned.
    /// @param to The address to which tokens are transferred or minted.
    /// @param value The amount of tokens to transfer, mint, or burn.
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        if (from != address(0)) {
            evc.requireAccountStatusCheck(from);
        }
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev Overriden due to the conflict with the Context definition.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }
}

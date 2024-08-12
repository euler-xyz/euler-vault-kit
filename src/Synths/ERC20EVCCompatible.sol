// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20, Context} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Permit.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title ERC20EVCCompatible
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice ERC20EVCCompatible is an ERC20-compatible token with the EVC support.
abstract contract ERC20EVCCompatible is EVCUtil, ERC20Permit {
    constructor(address _evc_, string memory _name_, string memory _symbol_)
        EVCUtil(_evc_)
        ERC20(_name_, _symbol_)
        ERC20Permit(_name_)
    {}

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev Overridden due to the conflict with the Context definition.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }
}

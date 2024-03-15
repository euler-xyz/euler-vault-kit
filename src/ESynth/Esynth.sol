// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IESynth} from "./IESynth.sol";
import {ERC20Collateral, ERC20, Context} from "../ERC20Collateral/ERC20Collateral.sol";
import {IEVC, EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

interface IVault {
    function increaseCash(uint256 amount) external;
    function decreaseCash(uint256 amount) external;
}

contract ESynth is IESynth, ERC20Collateral, Ownable {
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    mapping(address => MinterData) public minters;

    event MinterCapacitySet(address indexed minter, uint256 capacity);
    error E_CapacityReached();

    constructor(IEVC evc_, string memory name_, string memory symbol_) ERC20Collateral(evc_, name_, symbol_) Ownable(msg.sender) {}

    /// @notice Sets the minting capacity for a minter.
    /// @dev Can only be called by the owner of the contract.
    /// @param minter The address of the minter to set the capacity for.
    /// @param capacity The capacity to set for the minter.
    function setCapacity(address minter, uint128 capacity) external onlyOwner {
        minters[minter].capacity = capacity;
        emit MinterCapacitySet(minter, capacity);
    }

    /// @notice Mints a certain amount of tokens to the account.
    /// @dev Can only be called by an address that has sufficient minting capacity.
    /// @param account The account to mint the tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external override nonReentrant {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if(minterCache.capacity < uint256(minterCache.minted) + amount) {
            revert E_CapacityReached();
        }

        minterCache.minted += uint128(amount);
        minters[sender] = minterCache;

        _mint(account, amount);
    }

    /// @notice Burns a certain amount of tokens from the accounts balance. Requires the account to have an allowance for the sender.
    /// @dev Performs account status check as this would possibly put an account into an undercollateralized state.
    /// @param account The account to burn the tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint256 amount) external override nonReentrant {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if(account != sender) {
            _spendAllowance(account, sender, amount);
        }

        // If burning more than minted
        amount = amount > minterCache.minted ? minterCache.minted : amount;

        minterCache.minted -= uint128(amount);
        minters[sender] = minterCache;

        _burn(account, amount);
    }

    /// @notice Increase cash available in an attached vault.
    /// @param vault The vault to increase the cash for.
    /// @param amount The amount of cash to increase.
    function increaseCash(address vault, uint256 amount) external onlyOwner nonReentrant {
        IVault(vault).increaseCash(amount);
    }

    /// @notice Decrease cash available in an attached vault.
    /// @param vault The vault to decrease the cash for.
    /// @param amount The amount of cash to decrease.
    function decreaseCash(address vault, uint256 amount) external onlyOwner nonReentrant {
        IVault(vault).decreaseCash(amount);
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev Overriden due to the conflict with the Context definition.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override(ERC20Collateral, Context) returns (address) {
        return ERC20Collateral._msgSender();
    }
}
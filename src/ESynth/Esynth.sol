// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Context} from "openzeppelin/utils/Context.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {IESynth} from "./IESynth.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

interface IVault {
    function increaseCash(uint256 amount) external;
    function decreaseCash(uint256 amount) external;
}

contract ESynth is EVCUtil, IESynth, ERC20Permit, Ownable, ReentrancyGuard {
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    mapping(address => MinterData) public minters;

    event MinterCapacitySet(address indexed minter, uint256 capacity);
    error E_CapacityReached();

    constructor(IEVC evc_, string memory name_, string memory symbol_) EVCUtil(evc_) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(msg.sender) {

    }

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
    
    /// @notice Transfers a certain amount of tokens to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of tokens from a sender to a recipient.
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

    function _msgSender() internal view override(Context, EVCUtil) returns (address sender) {
        return EVCUtil._msgSender();
    }
}
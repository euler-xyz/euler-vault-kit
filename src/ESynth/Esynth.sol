// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Context} from "openzeppelin/utils/Context.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IESynth} from "./IESynth.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

contract ESynth is EVCUtil, IESynth, ERC20Permit, Ownable, ReentrancyGuard {
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    mapping(address => MinterData) public minters;

    event MinterCapacitySet(address indexed minter, uint256 capacity);

    error E_TooLargeAmount();
    error E_CapacityReached();
    error E_NotMinter();

    /// @notice Modifier to require an account status check on the EVC.
    /// @dev Calls `requireAccountStatusCheck` function from EVC for the specified account after the function body.
    /// @param account The address of the account to check.
    modifier requireAccountStatusCheck(address account) {
        _;
        evc.requireAccountStatusCheck(account);
    }

    constructor(IEVC evc_, string memory name_, string memory symbol_) EVCUtil(evc_) ERC20(name_, symbol_) ERC20Permit(name_) {

    }

    /// @notice Sets the minting capacity for a minter.
    /// @dev Can only be called by the owner of the contract.
    /// @param minter The address of the minter to set the capacity for.
    /// @param capacity The capacity to set for the minter.
    function setCapacity(address minter, uint256 capacity) external onlyOwner {
        if(capacity > type(uint128).max) {
            revert E_TooLargeAmount();
        }
        minters[minter].capacity = uint128(capacity);
        emit MinterCapacitySet(minter, capacity);
    }

    /// @notice Mints a certain amount of tokens to the account.
    /// @dev Can only be called by an address that has sufficient minting capacity.
    /// @param account The account to mint the tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external override {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if(amount > type(uint128).max) {
            revert E_TooLargeAmount();
        }

        uint128 amount128 = uint128(amount);

        if(minterCache.capacity < minterCache.minted + amount128) {
            revert E_CapacityReached();
        }

        minterCache.minted += amount128;
        minters[sender] = minterCache;

        _mint(account, amount);
    }

    /// @notice Burns a certain amount of tokens from the accounts balance. Requires the account to have an allowance for the sender.
    /// @dev Performs account status check as this would possibly put an account into an undercollateralized state.
    /// @param account The account to burn the tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint256 amount) external override callThroughEVC nonReentrant requireAccountStatusCheck(account) {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if(amount > type(uint128).max) {
            revert E_TooLargeAmount();
        }

        if(account != sender) {
            _spendAllowance(account, sender, amount);
        }

        uint128 amount128 = uint128(amount);

        // If burning more than minted
        if(amount128 > minterCache.minted) {
            minterCache.minted = 0;
        } else {
            minterCache.minted -= amount128;
        }
        minters[sender] = minterCache;

        _burn(account, amount);
    }

    /// @notice Transfers a certain amount of tokens to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(
        address to,
        uint256 amount
    ) public virtual override callThroughEVC nonReentrant requireAccountStatusCheck(_msgSender()) returns (bool) {
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
    ) public virtual override callThroughEVC nonReentrant requireAccountStatusCheck(from) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function _msgSender() internal view override(Context, EVCUtil) returns (address sender) {
        return EVCUtil._msgSender();
    }

}
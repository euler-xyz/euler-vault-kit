// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC20Collateral, ERC20, Context} from "../ERC20Collateral/ERC20Collateral.sol";
import {IEVC, EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVault} from "../EVault/IEVault.sol";

contract ESynth is ERC20Collateral, Ownable {
    constructor(IEVC evc_, string memory name_, string memory symbol_)
        ERC20Collateral(evc_, name_, symbol_)
        Ownable(msg.sender)
    {}

    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    error E_CapacityReached();

    event MinterCapacitySet(address indexed minter, uint256 capacity);

    mapping(address => MinterData) public minters;

    // @notice Sets the minting capacity for a minter.
    /// @dev Can only be called by the owner of the contract.
    /// @param minter The address of the minter to set the capacity for.
    /// @param capacity The capacity to set for the minter.

    function setCapacity(address minter, uint128 capacity) external onlyOwner {
        minters[minter].capacity = capacity;
        emit MinterCapacitySet(minter, capacity);
    }

    /// @notice Mints a certain amount of tokens to the account.
    /// @param account The account to mint the tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint128 amount) external nonReentrant {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if (minterCache.capacity < minterCache.minted + amount) {
            revert E_CapacityReached();
        }
        minterCache.minted += amount;
        minters[sender] = minterCache;

        _mint(account, amount);
    }

    /// @notice Burns a certain amount of tokens from the accounts balance. Requires the account to have an allowance for the sender.
    /// @param account The account to burn the tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint128 amount) external nonReentrant {
        address sender = _msgSender();
        MinterData storage minterCache = minters[sender];

        if (account != sender && sender != owner()) {
            _spendAllowance(account, sender, amount);
        }

        // If burning more than minted, reset minted to 0
        if (amount > minterCache.minted) {
            minterCache.minted = 0;
        } else {
            minterCache.minted -= amount;
        }
        minters[sender] = minterCache;

        _burn(account, amount);
    }

    /// @notice Deposit cash in the attached vault.
    /// @param vault The vault to deposit the cash in.
    /// @param amount The amount of cash to deposit.
    function deposit(address vault, uint256 amount) external onlyOwner {
        _approve(address(this), vault, amount, true);
        IEVault(vault).deposit(amount, address(this));
    }

    /// @notice Withdraw cash from the attached vault.
    /// @param vault The vault to withdraw the cash from.
    /// @param amount The amount of cash to withdraw.
    function withdraw(address vault, uint256 amount) external onlyOwner {
        IEVault(vault).withdraw(amount, address(this), address(this));
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev Overriden due to the conflict with the Context definition.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (ERC20Collateral, Context) returns (address) {
        return ERC20Collateral._msgSender();
    }
}

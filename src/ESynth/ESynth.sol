// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract ESSynth is ERC20, Ownable {
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    mapping(address => MinterData) public minters;
    mapping(address => address) public surplusReceiverForMinter;

    error E_TooLargeAmount();
    error E_CapacityReached();
    error E_NotMinter();
    error E_MinterToMinter();
    error E_MsgSenderNotMinter();

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    }

    function setCapacity(address minter, uint128 capacity) external onlyOwner {
        // Disallow a minter becoming a non minter to prevent issues with virtual balances
        if(capacity == 0) capacity = 1;
        minters[minter].capacity = capacity;
    }

    function setSurplusReceiverForMinter(address minter, address receiver) external onlyOwner {
        surplusReceiverForMinter[minter] = receiver;
        // TODO consider adding a callback
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint amount) public override returns(bool) {
        MinterData memory fromMinterCache = minters[from];
        MinterData memory toMinterCache = minters[to];
        bool fromIsMinter = fromMinterCache.capacity != 0;
        bool toIsMinter = toMinterCache.capacity != 0;
        
        // No minter involved use default behaviour
        if(!fromIsMinter && !toIsMinter) {
            return super.transferFrom(from, to, amount);
        }

        // Minting to Minter disallowed
        if(fromIsMinter && toIsMinter) {
            revert E_MinterToMinter();
        }

        // Minting
        if(fromIsMinter) {
            return _doMint(fromMinterCache, from, to, amount);
        } 

        // default case sending to minter (burning)
        return _doBurn(toMinterCache, from, to, amount);
    }

    function _doMint(MinterData memory fromMinterCache, address from, address to, uint256 amount) internal returns (bool) {
        if(msg.sender != from) {
            revert E_MsgSenderNotMinter();
        }

        if (amount > type(uint128).max) revert E_TooLargeAmount();
        if (fromMinterCache.minted + amount > fromMinterCache.capacity) revert E_CapacityReached();

        minters[from].minted = fromMinterCache.minted + uint128(amount);
        // TODO mint event
        _mint(to, amount);

        return true;
    }

    function _doBurn(MinterData memory toMinterCache, address from, address to, uint256 amount) internal returns (bool) {
       if (amount > type(uint128).max) revert E_TooLargeAmount();

        // If burning more than minted, set minted to 0 and mint surplus to surplus receiver
        if (amount > toMinterCache.minted) {
            minters[to].minted = 0;
            address receiver = surplusReceiverForMinter[to];
            if(receiver != address(0)) {
                _mint(receiver, amount - toMinterCache.minted);
            }
        } else {
            minters[to].minted -= uint128(amount);
        }

        // Check allowance if not burning own tokens
        if (from != msg.sender) {
            uint allowed = allowance(from, msg.sender); // Saves gas for limited approval
            if(allowed != type(uint).max) _approve(from, msg.sender, allowed - amount);
        }

        _burn(from, amount);

        return true; 
    }

    function balanceOf(address account) public view override returns (uint) {
        MinterData memory minterData = minters[account];
        
        // If is minter overwrite balanceOf
        if(minterData.capacity != 0) {
            // Minted more than current capacity
            if(minterData.minted > minterData.capacity) {
                return 0;
            }

            return minterData.capacity - minterData.minted;
        }

        return super.balanceOf(account);
    }

    function getMinter(address minter) external view returns (MinterData memory) {
        return minters[minter];
    }
}
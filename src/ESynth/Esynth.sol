// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IESynth} from "./IESynth.sol";

contract ESynth is IESynth, ERC20Permit, Ownable {
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    mapping(address => MinterData) public minters;

    error E_TooLargeAmount();
    error E_CapacityReached();
    error E_NotMinter();

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) ERC20Permit(name_) {

    }

    function setCapacity(address minter, uint128 capacity) external onlyOwner {
        minters[minter].capacity = capacity;
        // TODO emit event
    }

    function mint(address account, uint256 amount) external override {
        MinterData storage minterCache = minters[msg.sender];

        if(amount > type(uint128).max) {
            revert E_TooLargeAmount();
        }

        uint128 amount128 = uint128(amount);

        if(minterCache.capacity < minterCache.minted + amount128) {
            revert E_CapacityReached();
        }

        minterCache.minted += amount128;
        minters[msg.sender] = minterCache;

        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external override {
        MinterData storage minterCache = minters[msg.sender];

        if(amount > type(uint128).max) {
            revert E_TooLargeAmount();
        }

        _spendAllowance(account, msg.sender, amount);

        uint128 amount128 = uint128(amount);

        // If burning more than minted
        if(amount128 > minterCache.minted) {
            minterCache.minted = 0;
        } else {
            minterCache.minted -= amount128;
        }
        minters[msg.sender] = minterCache;

        _burn(account, amount);
    }

}
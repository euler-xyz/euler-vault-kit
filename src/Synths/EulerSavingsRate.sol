// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title EulerSavingsRate
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EulerSavingsRate is a ERC4626-compatible vault with the EVC support which allows users to deposit the
/// underlying asset and receive interest in the form of the same underlying asset.
/// @dev Do NOT use with fee on transfer tokens
/// @dev Do NOT use with rebasing tokens
contract EulerSavingsRate is EVCUtil, ERC4626 {
    using Math for uint256;

    uint8 internal constant UNLOCKED = 1;
    uint8 internal constant LOCKED = 2;

    /// @notice The virtual amount added to total shares and total assets.
    uint256 internal constant VIRTUAL_AMOUNT = 1e6;
    /// @notice At least 10 times the virtual amount of shares should exist for gulp to be enabled
    uint256 internal constant MIN_SHARES_FOR_GULP = VIRTUAL_AMOUNT * 10;

    uint256 public constant INTEREST_SMEAR = 2 weeks;

    struct ESRSlot {
        uint40 lastInterestUpdate;
        uint40 interestSmearEnd;
        uint168 interestLeft;
        uint8 locked;
    }

    /// @notice Multiple state variables stored in a single storage slot.
    ESRSlot internal esrSlot;
    /// @notice The total assets accounted for in the vault.
    uint256 internal _totalAssets;

    error Reentrancy();

    event Gulped(uint256 gulped, uint256 interestLeft);
    event InterestUpdated(uint256 interestAccrued, uint256 interestLeft);

    modifier nonReentrant() {
        if (esrSlot.locked == LOCKED) revert Reentrancy();

        esrSlot.locked = LOCKED;
        _;
        esrSlot.locked = UNLOCKED;
    }

    constructor(address _evc, address _asset, string memory _name, string memory _symbol)
        EVCUtil(_evc)
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol)
    {
        esrSlot.locked = UNLOCKED;
    }

    /// @notice Returns the total assets deposited + any accrued interest.
    /// @return The total assets deposited + any accrued interest.
    function totalAssets() public view override returns (uint256) {
        return _totalAssets + interestAccrued();
    }

    /// @notice Deposits a certain amount of assets to the vault.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The recipient of the shares.
    /// @return The amount of shares minted.
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @notice Mints a certain amount of shares to the account.
    /// @param shares The amount of assets to mint.
    /// @param receiver The account to mint the shares to.
    /// @return The amount of assets spent.
    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @notice Withdraws a certain amount of assets from the vault.
    /// @dev Overwritten to update the accrued interest and update _totalAssets.
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The recipient of the assets.
    /// @param owner The holder of shares to burn.
    /// @return The amount of shares burned.
    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        // Move interest to totalAssets
        updateInterestAndReturnESRSlotCache();
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems a certain amount of shares for assets.
    /// @dev Overwritten to update the accrued interest and update _totalAssets.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The recipient of the assets.
    /// @param owner The account from which the shares are redeemed.
    /// @return The amount of assets redeemed.
    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        // Move interest to totalAssets
        updateInterestAndReturnESRSlotCache();
        return super.redeem(shares, receiver, owner);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        return assets.mulDiv(totalSupply() + VIRTUAL_AMOUNT, totalAssets() + VIRTUAL_AMOUNT, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        return shares.mulDiv(totalAssets() + VIRTUAL_AMOUNT, totalSupply() + VIRTUAL_AMOUNT, rounding);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        _totalAssets = _totalAssets + assets;
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _totalAssets = _totalAssets - assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Smears any donations to this vault as interest.
    function gulp() public nonReentrant {
        ESRSlot memory esrSlotCache = updateInterestAndReturnESRSlotCache();

        // Do not gulp if total supply is too low
        if (totalSupply() < MIN_SHARES_FOR_GULP) return;

        uint256 assetBalance = IERC20(asset()).balanceOf(address(this));
        uint256 toGulp = assetBalance - _totalAssets - esrSlotCache.interestLeft;

        uint256 maxGulp = type(uint168).max - esrSlotCache.interestLeft;
        if (toGulp > maxGulp) toGulp = maxGulp; // cap interest, allowing the vault to function

        esrSlotCache.lastInterestUpdate = uint40(block.timestamp);
        esrSlotCache.interestSmearEnd = uint40(block.timestamp + INTEREST_SMEAR);
        esrSlotCache.interestLeft += uint168(toGulp); // toGulp <= maxGulp <= max uint168

        // write esrSlotCache back to storage in a single SSTORE
        esrSlot = esrSlotCache;

        emit Gulped(toGulp, esrSlotCache.interestLeft);
    }

    /// @notice Updates the interest and returns the ESR storage slot cache.
    /// @return The ESR storage slot cache.
    function updateInterestAndReturnESRSlotCache() public returns (ESRSlot memory) {
        ESRSlot memory esrSlotCache = esrSlot;
        uint256 accruedInterest = interestAccruedFromCache(esrSlotCache);

        if (accruedInterest > 0) {
            // it's safe to down-cast because the accrued interest is a fraction of interest left
            esrSlotCache.interestLeft -= uint168(accruedInterest);
            esrSlotCache.lastInterestUpdate = uint40(block.timestamp);
            // write esrSlotCache back to storage in a single SSTORE
            esrSlot = esrSlotCache;
            // Move interest accrued to totalAssets
            _totalAssets = _totalAssets + accruedInterest;

            emit InterestUpdated(accruedInterest, esrSlotCache.interestLeft);
        }

        return esrSlotCache;
    }

    /// @notice Returns the amount of interest accrued.
    /// @return The amount of interest accrued.
    function interestAccrued() public view returns (uint256) {
        return interestAccruedFromCache(esrSlot);
    }

    function interestAccruedFromCache(ESRSlot memory esrSlotCache) internal view returns (uint256) {
        // If distribution ended, full amount is accrued
        if (block.timestamp >= esrSlotCache.interestSmearEnd) {
            return esrSlotCache.interestLeft;
        }

        // If just updated return 0
        if (esrSlotCache.lastInterestUpdate == block.timestamp) {
            return 0;
        }

        // Else return what has accrued
        uint256 totalDuration = esrSlotCache.interestSmearEnd - esrSlotCache.lastInterestUpdate;
        uint256 timePassed = block.timestamp - esrSlotCache.lastInterestUpdate;

        return esrSlotCache.interestLeft * timePassed / totalDuration;
    }

    /// @notice Returns the ESR storage slot as a struct.
    /// @return The ESR storage slot as a struct.
    function getESRSlot() public view returns (ESRSlot memory) {
        return esrSlot;
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}

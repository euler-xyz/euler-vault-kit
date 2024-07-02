// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title EulerSavingsRate
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EulerSavingsRate is a ERC4626-compatible vault which allows users to deposit the underlying asset and receive
/// interest in the form of the same underlying asset. On withdraw, redeem and transfers, the account status checks must be
/// requested for the account which health might be negatively affected. Thanks to that, the shares of the EulerSavingsRate
/// vault might be used as collateral by other EVC-compatible vaults.
/// @dev Do NOT use with fee on transfer tokens
/// @dev Do NOT use with rebasing tokens
contract EulerSavingsRate is EVCUtil, ERC4626 {
    using Math for uint256;

    uint8 internal constant UNLOCKED = 1;
    uint8 internal constant LOCKED = 2;

    /// @notice The virtual amount added to total shares and total assets.
    uint256 internal constant VIRTUAL_AMOUNT = 1e6;
    uint256 internal constant MIN_SHARES_FOR_GULP = VIRTUAL_AMOUNT * 10; // At least 10 times the virtual amount of shares should exist for gulp to be enabled

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

    /// @notice Modifier to require an account status check on the EVC.
    /// @dev Calls `requireAccountStatusCheck` function from EVC for the specified account after the function body.
    /// @param account The address of the account to check.
    modifier requireAccountStatusCheck(address account) {
        _;
        evc.requireAccountStatusCheck(account);
    }

    modifier nonReentrant() {
        if (esrSlot.locked == LOCKED) revert Reentrancy();

        esrSlot.locked = LOCKED;
        _;
        esrSlot.locked = UNLOCKED;
    }

    constructor(IEVC _evc, address _asset, string memory _name, string memory _symbol)
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

    /// @notice Returns the maximum amount of shares that can be redeemed by the specified address.
    /// @dev If the account has a controller set it's possible the withdrawal will be reverted by the controller, thus
    /// we return 0.
    /// @param owner The account owner.
    /// @return The maximum amount of shares that can be redeemed.
    function maxRedeem(address owner) public view override returns (uint256) {
        // Max redeem can potentially be 0 if there is a liability
        if (evc.getControllers(owner).length > 0) {
            return 0;
        }

        return super.maxRedeem(owner);
    }

    /// @notice Returns the maximum amount of assets that can be withdrawn by the specified address.
    /// @dev If the account has a controller set it's possible the withdrawal will be reverted by the controller, thus
    /// we return 0.
    /// @param owner The account owner.
    /// @return The maximum amount of assets that can be withdrawn.
    function maxWithdraw(address owner) public view override returns (uint256) {
        // Max withdraw can potentially be 0 if there is a liability
        if (evc.getControllers(owner).length > 0) {
            return 0;
        }

        return super.maxWithdraw(owner);
    }

    /// @notice Transfers a certain amount of tokens to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount)
        public
        override (ERC20, IERC20)
        nonReentrant
        requireAccountStatusCheck(_msgSender())
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of tokens from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        override (ERC20, IERC20)
        nonReentrant
        requireAccountStatusCheck(from)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
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

    /// @notice Deposits a certain amount of assets to the vault.
    /// @dev Overwritten to not call maxWithdraw which would return 0 if there is a controller set, update the accrued interest and update _totalAssets.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The recipient of the shares.
    /// @return The amount of shares minted.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        requireAccountStatusCheck(owner)
        returns (uint256)
    {
        // Move interest to totalAssets
        updateInterestAndReturnESRSlotCache();

        uint256 maxAssets = _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
        if (maxAssets < assets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        _totalAssets = _totalAssets - assets;

        return shares;
    }

    /// @notice Redeems a certain amount of shares for assets.
    /// @dev Overwritten to not call maxRedeem which would return 0 if there is a controller set, update the accrued interest and update _totalAssets.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The recipient of the assets.
    /// @return The amount of assets redeemed.
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        requireAccountStatusCheck(owner)
        returns (uint256)
    {
        // Move interest to totalAssets
        updateInterestAndReturnESRSlotCache();

        uint256 maxShares = balanceOf(owner);
        if (maxShares < shares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        _totalAssets = _totalAssets - assets;

        return assets;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        return assets.mulDiv(totalSupply() + VIRTUAL_AMOUNT, totalAssets() + VIRTUAL_AMOUNT, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        return shares.mulDiv(totalAssets() + VIRTUAL_AMOUNT, totalSupply() + VIRTUAL_AMOUNT, rounding);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        _totalAssets = _totalAssets + assets;
        super._deposit(caller, receiver, assets, shares);
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

        // it's safe to down-cast because the accrued interest is a fraction of interest left
        esrSlotCache.interestLeft -= uint168(accruedInterest);
        esrSlotCache.lastInterestUpdate = uint40(block.timestamp);
        // write esrSlotCache back to storage in a single SSTORE
        esrSlot = esrSlotCache;
        // Move interest accrued to totalAssets
        _totalAssets = _totalAssets + accruedInterest;

        emit InterestUpdated(accruedInterest, esrSlotCache.interestLeft);

        return esrSlotCache;
    }

    /// @notice Returns the amount of interest accrued.
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

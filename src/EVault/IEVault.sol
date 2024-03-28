// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IVault as IEVCVault} from "ethereum-vault-connector/interfaces/IVault.sol";

// Full interface of EVault and all it's modules

interface IInitialize {
    /// @notice Initialization of the newly deployed proxy contract
    /// @param proxyCreator Account which created the proxy or should be the initial governor
    function initialize(address proxyCreator) external;
}

interface IERC20 {
    /// @notice Vault share token (eToken) name, ie "Euler Vault: DAI"
    function name() external view returns (string memory);

    /// @notice Vault share token (eToken) symbol, ie "eDAI"
    function symbol() external view returns (string memory);

    /// @notice Decimals, always normalised to 18
    function decimals() external view returns (uint8);

    /// @notice Sum of all eToken balances
    function totalSupply() external view returns (uint256);

    /// @notice Balance of a particular account, in eTokens
    function balanceOf(address account) external view returns (uint256);

    /// @notice Retrieve the current allowance
    /// @param holder The account holding the eTokens
    /// @param spender Trusted address
    function allowance(address holder, address spender) external view returns (uint256);

    /// @notice Transfer eTokens to another address
    /// @param to Recipient account
    /// @param amount In shares.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Transfer eTokens from one address to another
    /// @param from This address must've approved the to address
    /// @param to Recipient account
    /// @param amount In shares
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// @notice Allow spender to access an amount of your eTokens
    /// @param spender Trusted address
    /// @param amount Use max uint for "infinite" allowance
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IToken is IERC20 {
    /// @notice Transfer the full eToken balance of an address to another
    /// @param from This address must've approved the to address
    /// @param to Recipient account
    function transferFromMax(address from, address to) external returns (bool);
}

interface IERC4626 {
    /// @notice Vault underlying asset
    function asset() external view returns (address);

    /// @notice Total amount of managed assets
    function totalAssets() external view returns (uint256);

    /// @notice Calculate amount of assets corresponding to the requested shares amount
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Calculate amount of shares corresponding to the requested assets amount
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Fetch the maximum amount of assets a user can deposit
    function maxDeposit(address account) external view returns (uint256);

    /// @notice Calculate an amount of shares that would be created by depositing assets
    /// @param assets Amount of assets deposited
    /// @return Amount of shares received
    function previewDeposit(uint256 assets) external view returns (uint256);

    /// @notice Fetch the maximum amount of shares a user can mint
    function maxMint(address account) external view returns (uint256);

    /// @notice Calculate an amount of assets that would be required to mint requested amount of shares
    /// @param shares Amount of shares to be minted
    /// @return Required amount of assets
    function previewMint(uint256 shares) external view returns (uint256);

    /// @notice Fetch the maximum amount of assets a user is allowed to withdraw
    /// @param owner Account holding the shares
    /// @return The maximum amount of assets the owner is allowed to withdraw
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Calculate the amount of shares that will be burned when withdrawing requested amount of assets
    /// @param assets Amount of assets withdrawn
    /// @return Amount of shares burned
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Fetch the maximum amount of shares a user is allowed to redeem for assets
    /// @param owner Account holding the shares
    /// @return The maximum amount of shares the owner is allowed to redeem
    function maxRedeem(address owner) external view returns (uint256);

    /// @notice Calculate the amount of assets that will be transferred when redeeming requested amount of shares
    /// @param shares Amount of shares redeemed
    /// @return Amount of assets transferred
    function previewRedeem(uint256 shares) external view returns (uint256);

    /// @notice Transfer requested amount of underlying tokens from sender to the vault pool in return for shares
    /// @param amount Amount of assets to deposit (use max uint256 for full underlying token balance)
    /// @param receiver An account to receive the shares
    /// @return Amount of shares minted
    /// @dev Deposit will round down the amount of assets that are converted to shares. To prevent losses consider using mint instead.
    function deposit(uint256 amount, address receiver) external returns (uint256);

    /// @notice Transfer underlying tokens from sender to the vault pool in return for requested amount of shares
    /// @param amount Amount of shares to be minted
    /// @param receiver An account to receive the shares
    /// @return Amount of assets deposited
    function mint(uint256 amount, address receiver) external returns (uint256);

    /// @notice Transfer requested amount of underlying tokens from the vault and decrease account's shares balance
    /// @param amount Amount of assets to withdraw
    /// @param receiver Account to receive the withdrawn assets
    /// @param owner Account holding the shares to burn
    /// @return Amount of shares burned
    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256);

    /// @notice Burn requested shares and transfer corresponding underlying tokens from the vault to the receiver
    /// @param amount Amount of shares to burn (use max uint256 to burn full owner balance)
    /// @param receiver Account to receive the withdrawn assets
    /// @param owner Account holding the shares to burn.
    /// @return Amount of assets transferred
    function redeem(uint256 amount, address receiver, address owner) external returns (uint256);
}

interface IVault is IERC4626 {
    /// @notice Balance of the fees accumulator, in eTokens
    function accumulatedFees() external view returns (uint256);

    /// @notice Balance of the fees accumulator, in underlying units
    function accumulatedFeesAssets() external view returns (uint256);

    /// @notice Address of the original vault creator
    function creator() external view returns (address);

    /// @notice Creates shares for the receiver, from excess asset balances of the vault (not accounted for in `cash`)
    /// @param amount Amount of assets to claim (use max uint256 to claim all available assets)
    /// @param receiver An account to receive the shares
    /// @return Amount of shares minted
    /// @dev Could be used as an alternative deposit flow in certain scenarios. E.g. swap directly to the vault, call `skim` to claim deposit.
    function skim(uint256 amount, address receiver) external returns (uint256);
}

interface IBorrowing {
    /// @notice Sum of all outstanding debts, in underlying units (increases as interest is accrued)
    function totalBorrows() external view returns (uint256);

    /// @notice Sum of all outstanding debts, in underlying units scaled up by INTERNAL_DEBT_PRECISION bits
    function totalBorrowsExact() external view returns (uint256);

    /// @notice Balance of vault assets as tracked by deposits/withdrawals and borrows/repays
    function cash() external view returns (uint256);

    /// @notice Debt owed by a particular account, in underlying units
    function debtOf(address account) external view returns (uint256);

    /// @notice Debt owed by a particular account, in underlying units scaled up by INTERNAL_DEBT_PRECISION bits
    function debtOfExact(address account) external view returns (uint256);

    /// @notice Retrieves the current interest rate for an asset
    /// @return The interest rate in yield-per-second, scaled by 10**27
    function interestRate() external view returns (uint256);

    /// @notice Retrieves the current interest rate accumulator for an asset
    /// @return An opaque accumulator that increases as interest is accrued
    function interestAccumulator() external view returns (uint256);

    /// @notice Retrieves amount of the collateral that is being actively used to support the debt of the account.
    function collateralUsed(address collateral, address account) external view returns (uint256);

    /// @notice Address of the sidecar DToken
    function dToken() external view returns (address);

    /// @notice Transfer underlying tokens from the vault to the sender, and increase sender's debt
    /// @param amount Amount of assets to borrow (use max uint256 for all available tokens)
    /// @param receiver Account receiving the borrowed tokens
    /// @return Amount of assets borrowed
    function borrow(uint256 amount, address receiver) external returns (uint256);

    /// @notice Transfer underlying tokens from the sender to the vault, and decrease receiver's debt
    /// @param amount Amount of debt to repay in assets (use max uint256 for full debt)
    /// @param receiver Account holding the debt to be repaid
    /// @return Amount of assets repaid
    function repay(uint256 amount, address receiver) external returns (uint256);

    /// @notice Mint shares and a corresponding amount of debt ("self-borrow")
    /// @param amount In asset units
    /// @param sharesReceiver Account to receive the created shares
    /// @return Amount of shares created
    function loop(uint256 amount, address sharesReceiver) external returns (uint256);

    /// @notice Pay off liability with shares ("self-repay")
    /// @param amount In asset units (use max uint256 to repay the debt in full or up to the available underlying balance)
    /// @param debtFrom Account to remove debt from by burning sender's shares
    /// @return Amount of shares burned
    function deloop(uint256 amount, address debtFrom) external returns (uint256);

    /// @notice Take over debt from another account
    /// @param amount Amount of debt in asset units (use max uint256 for all the account's debt)
    /// @param from Account to pull the debt from
    /// @return Amount of debt pulled in asset units.
    function pullDebt(uint256 amount, address from) external returns (uint256);

    /// @notice Request a flash-loan. A onFlashLoan() callback in msg.sender will be invoked, which must repay the loan to the main Euler address prior to returning.
    /// @param amount In asset units
    /// @param data Passed through to the onFlashLoan() callback, so contracts don't need to store transient data in storage
    function flashLoan(uint256 amount, bytes calldata data) external;

    /// @notice Updates interest accumulator and totalBorrows, credits reserves, re-targets interest rate, and logs vault status
    function touch() external;
}

interface ILiquidation {
    /// @notice Checks to see if a liquidation would be profitable, without actually doing anything
    /// @param liquidator Address that will initiate the liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Collateral which is to be seized
    /// @return maxRepay Max amount of debt that can be repaid, in asset units
    /// @return maxYield Yield in collateral corresponding to max allowed amount of debt to be repaid, in collateral balance (shares for vaults)
    function checkLiquidation(address liquidator, address violator, address collateral)
        external
        view
        returns (uint256 maxRepay, uint256 maxYield);

    /// @notice Attempts to perform a liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Collateral which is to be seized
    /// @param repayAssets The amount of underlying debt to be transferred from violator to sender, in asset units (use max uint256 to repay the maximum possible amount).
    /// @param minYieldBalance The minimum acceptable amount of collateral to be transferred from violator to sender, in collateral balance units (shares for vaults)
    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) external;
}

interface IRiskManager is IEVCVault {
    /// @notice Retrieve account's total liquidity
    /// @param account Account holding debt in this vault
    /// @param liquidation Flag to indicate if the calculation should be performed in liquidation vs account status check mode, where different LTV values might apply.
    /// @return collateralValue Total risk adjusted value of all collaterals in unit of account
    /// @return liabilityValue Value of debt in unit of account
    function accountLiquidity(address account, bool liquidation)
        external
        view
        returns (uint256 collateralValue, uint256 liabilityValue);

    /// @notice Retrieve account's liquidity per collateral
    /// @param account Account holding debt in this vault
    /// @param liquidation Flag to indicate if the calculation should be performed in liquidation vs account status check mode, where different LTV values might apply.
    /// @return collaterals Array of collaterals enabled
    /// @return collateralValues Array of risk adjusted collateral values corresponding to items in collaterals array. In unit of account
    /// @return liabilityValue Value of debt in unit of account
    function accountLiquidityFull(address account, bool liquidation)
        external
        view
        returns (address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue);

    /// @notice Release control of the account on EVC if no outstanding debt is present
    function disableController() external;

    /// @notice Checks the status of an account and reverts if account is not healthy
    /// @param account The address of the account to be checked
    /// @return magicValue Must return the bytes4 magic value 0xb168c58f (which is a selector of this function) when account status is valid, or revert otherwise.
    /// @dev Only callable by EVC during status checks
    function checkAccountStatus(address account, address[] calldata collaterals) external returns (bytes4);

    /// @notice Checks the status of the vault and reverts if caps are exceeded
    /// @return magicValue Must return the bytes4 magic value 0x4b3d1223 (which is a selector of this function) when account status is valid, or revert otherwise.
    /// @dev Only callable by EVC during status checks
    function checkVaultStatus() external returns (bytes4);
}

interface IBalanceForwarder {
    /// @notice Retrieve the address of rewards contract, tracking changes in account's balances
    function balanceTrackerAddress() external view returns (address);

    /// @notice Retrieves boolean indicating if the account opted in to forward balance changes to the rewards contract
    function balanceForwarderEnabled(address account) external view returns (bool);

    /// @notice Enables balance forwarding for the authenticated account
    /// @dev Only the authenticated account can enable balance forwarding for itself
    /// @dev Should call the IBalanceTracker hook with the current account's balance
    function enableBalanceForwarder() external;

    /// @notice Disables balance forwarding for the authenticated account
    /// @dev Only the authenticated account can disable balance forwarding for itself
    /// @dev Should call the IBalanceTracker hook with the account's balance of 0
    function disableBalanceForwarder() external;
}

interface IGovernance {
    /// @notice Retrieves the address of the governor
    function governorAdmin() external view returns (address);

    /// @notice Retrieves address of the governance fee receiver
    function feeReceiver() external view returns (address);

    /// @notice Retrieves the interest fee in effect for the vault
    /// @return Amount of interest that is redirected as a fee, as a fraction scaled by 1e4
    function interestFee() external view returns (uint16);

    /// @notice Looks up an asset's currently configured interest rate model
    /// @return Address of the interest rate contract or address zero to indicate 0% interest
    function interestRateModel() external view returns (address);

    /// @notice Retrieves the ProtocolConfig address
    function protocolConfigAddress() external view returns (address);

    /// @notice Retrieves the protocol fee share
    /// @return A percentage share of fees accrued belonging to the protocol. In wad scale (1e18)
    function protocolFeeShare() external view returns (uint256);

    /// @notice Retrieves the address which will receive protocol's fees
    function protocolFeeReceiver() external view returns (address);

    /// @notice Retrieves supply and borrow caps in AmountCap format
    function caps() external view returns (uint16 supplyCap, uint16 borrowCap);

    /// @notice Retrieves regular LTV, set for the collateral, which is used to determine the health of the account
    function borrowingLTV(address collateral) external view returns (uint16);

    /// @notice Retrieves current ramped value of LTV, which is used to determine liquidation penalty
    function liquidationLTV(address collateral) external view returns (uint16);

    /// @notice Retrieves LTV detailed config for a collateral
    /// @param collateral Collateral asset
    /// @return targetTimestamp the timestamp when the ramp ends
    /// @return targetLTV current regular LTV or target LTV that the ramped LTV will reach after ramp is over
    /// @return rampDuration ramp duration in seconds
    /// @return originalLTV previous LTV value, where the ramp starts
    function LTVFull(address collateral)
        external
        view
        returns (uint48 targetTimestamp, uint16 targetLTV, uint32 rampDuration, uint16 originalLTV);

    /// @notice Retrieves a list of collaterals with configured LTVs
    /// @return List of asset collaterals
    /// @dev The list can have duplicates. Returned assets could have the ltv disabled (set to zero)
    function LTVList() external view returns (address[] memory);

    /// @notice Retrieves a hook target and a bitmask indicating which operations call the hook target.
    function hookConfig() external view returns (address, uint32);

    /// @notice Retrieves a bitmask indicating enabled config flags.
    function configFlags() external view returns (uint32);

    /// @notice Address of EthereumVaultConnector contract
    function EVC() external view returns (address);

    /// @notice Retrieves a reference asset used for liquidity calculations
    function unitOfAccount() external view returns (address);

    /// @notice Retrieves the address of the oracle contract
    function oracle() external view returns (address);

    /// @notice Retrieves the Permit2 contract address
    function permit2Address() external view returns (address);

    /// @notice Splits accrued fees balance according to protocol fee share and transfers shares to the governor fee receiver and protocol fee receiver
    function convertFees() external;

    /// @notice Set a new eToken name
    function setName(string calldata newName) external;

    /// @notice Set a new eToken symbol
    function setSymbol(string calldata newSymbol) external;

    /// @notice Set a new governor address
    function setGovernorAdmin(address newGovernorAdmin) external;

    /// @notice Set a new governor fee receiver address
    function setFeeReceiver(address newFeeReceiver) external;

    /// @notice Set a new LTV config
    /// @param collateral Address of collateral to set LTV for
    /// @param ltv New LTV in 1e4 scale
    /// @param rampDuration Ramp duration in seconds
    function setLTV(address collateral, uint16 ltv, uint32 rampDuration) external;

    /// @notice Completely clears LTV configuratrion, signalling the collateral is not considered safe to liquidate anymore
    /// @param collateral Address of collateral
    function clearLTV(address collateral) external;

    /// @notice Set a new interest rate model contract
    /// @param newModel Address of the contract
    function setInterestRateModel(address newModel) external;

    /// @notice Set a new hook target and a new bitmap indicating which operations should call the hook target. Operations are defined in Constants.sol
    function setHookConfig(address newHookTarget, uint32 newHookedOps) external;

    /// @notice Set new bitmap indicating which config flags should be enabled. Flags are defined in Constants.sol
    function setConfigFlags(uint32 newConfigFlags) external;

    /// @notice Set new supply and borrow caps in AmountCap format
    function setCaps(uint16 supplyCap, uint16 borrowCap) external;

    /// @notice Set a new interest fee
    function setInterestFee(uint16 newFee) external;
}

interface IEVault is
    IInitialize,
    IToken,
    IVault,
    IBorrowing,
    ILiquidation,
    IRiskManager,
    IBalanceForwarder,
    IGovernance
{
    /// @notice Fetch address of the `Initialize` module
    function MODULE_INITIALIZE() external view returns (address);
    /// @notice Fetch address of the `Token` module
    function MODULE_TOKEN() external view returns (address);
    /// @notice Fetch address of the `Vault` module
    function MODULE_VAULT() external view returns (address);
    /// @notice Fetch address of the `Borrowing` module
    function MODULE_BORROWING() external view returns (address);
    /// @notice Fetch address of the `Liquidation` module
    function MODULE_LIQUIDATION() external view returns (address);
    /// @notice Fetch address of the `RiskManager` module
    function MODULE_RISKMANAGER() external view returns (address);
    /// @notice Fetch address of the `BalanceForwarder` module
    function MODULE_BALANCE_FORWARDER() external view returns (address);
    /// @notice Fetch address of the `Governance` module
    function MODULE_GOVERNANCE() external view returns (address);
}

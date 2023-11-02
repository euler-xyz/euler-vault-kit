// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IERC20 {
    /// @notice Pool name, ie "Euler Pool: DAI"
    function name() external view returns (string memory);

    /// @notice Pool symbol, ie "eDAI"
    function symbol() external view returns (string memory);

    /// @notice Decimals, always normalised to 18.
    function decimals() external view returns (uint8);

    /// @notice Sum of all share balances (non-increasing)
    function totalSupply() external view returns (uint);

    /// @notice Balance of a particular account, in internal book-keeping units (non-increasing)
    function balanceOf(address account) external view returns (uint);

    // /// @notice Retrieve the current allowance
    // /// @param holder The account holding the assets
    // /// @param spender Trusted address
    // function allowance(address holder, address spender) external view returns (uint);

    /// @notice Transfer eTokens to another address
    /// @param to Recipient account
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transfer(address to, uint amount) external returns (bool);

    // /// @notice Transfer the full eToken balance of an address to another
    // /// @param from This address must've approved the to address
    // /// @param to Recipient account
    // function transferFromMax(address from, address to) external returns (bool);

    /// @notice Transfer eTokens from one address to another
    /// @param from This address must've approved the to address
    /// @param to Recipient account
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transferFrom(address from, address to, uint amount) external returns (bool);

    // /// @notice Allow spender to access an amount of your eTokens
    // /// @param spender Trusted address
    // /// @param amount Use max uint for "infinite" allowance
    // function approve(address spender, uint amount) external returns (bool);
}

interface IERC4626 {
    /// @notice Vault underlying asset
    function asset() external view returns (address);

    /// @notice Total amount of managed assets
    function totalAssets() external view returns (uint);

    // /// @notice Calculate amount of assets corresponding to the requested shares amount
    // function convertToAssets(uint shares) external view returns (uint);

    // /// @notice Calculate amount of share corresponding to the requested assets amount
    // function convertToShares(uint assets) external view returns (uint);

    // /// @notice Fetch the maximum amount of assets a user can deposit
    // function maxDeposit(address) external view returns (uint);

    // /// @notice Calculate an amount of shares that would be created by depositing assets
    // /// @param assets Amount of assets deposited
    // /// @return Amount of shares received
    // function previewDeposit(uint assets) external view returns (uint);

    // /// @notice Fetch the maximum amount of shares a user can mint
    // function maxMint(address) external view returns (uint);

    // /// @notice Calculate an amount of assets that would be required to mint requested amount of shares
    // /// @param shares Amount of shares to be minted
    // /// @return Required amount of assets
    // function previewMint(uint shares) external view returns (uint);

    // /// @notice Fetch the maximum amount of assets a user is allowed to withdraw
    // /// @param owner Account holding the shares
    // /// @return The maximum amount of assets the owner is allowed to withdraw
    // function maxWithdraw(address owner) external view returns (uint);

    // /// @notice Calculate the amount of shares that will be burned when withdrawing requested amount of assets
    // /// @param assets Amount of assets withdrawn
    // /// @return Amount of shares burned
    // function previewWithdraw(uint assets) external view returns (uint);

    // /// @notice Fetch the maximum amount of shares a user is allowed to redeem for assets
    // /// @param owner Account holding the shares
    // /// @return The maximum amount of shares the owner is allowed to redeem
    // function maxRedeem(address owner) external view returns (uint);

    // /// @notice Calculate the amount of assets that will be transferred when redeeming requested amount of shares
    // /// @param shares Amount of shares redeemed
    // /// @return Amount of assets transferred
    // function previewRedeem(uint shares) external view returns (uint);

    /// @notice Transfer requested amount of underlying tokens from sender to the vault pool in return for shares
    /// @param assets In underlying units (use max uint for full underlying token balance)
    /// @param receiver An account to receive the shares
    /// @return Amount of shares minted
    function deposit(uint assets, address receiver) external returns (uint);

    // /// @notice Transfer underlying tokens from sender to the vault pool in return for requested amount of shares
    // /// @param shares Amount of share to be minted
    // /// @param receiver An account to receive the shares
    // /// @return Amount of assets deposited
    // function mint(uint shares, address receiver) external returns (uint);

    // /// @notice Transfer requested amount of underlying tokens from the vault and decrease account's shares
    // /// @param assets In underlying units (use max uint for full pool balance)
    // /// @param receiver Account to receive the withdrawn assets
    // /// @param owner Account holding the shares to burn
    // /// @return Amount of shares burned
    // function withdraw(uint assets, address receiver, address owner) external returns (uint);

    // /// @notice Burn requested shares and transfer corresponding underlying tokens from the vault to the receiver
    // /// @param shares Amount of shares to burn
    // /// @param receiver Account to receive the withdrawn assets
    // /// @param owner Account holding the shares to burn.
    // /// @return Amount of assets transferred
    // function redeem(uint shares, address receiver, address owner) external returns (uint);
}

interface IBorrowing {
    /// @notice Sum of all outstanding debts, in underlying units (increases as interest is accrued)
    function totalBorrows() external view returns (uint);

    /// @notice Sum of all outstanding debts, in underlying units scaled to 27 decimals
    function totalBorrowsExact() external view returns (uint);

    /// @notice Debt owed by a particular account, in underlying units
    function debtOf(address account) external view returns (uint);

    // /// @notice Debt owed by a particular account, in underlying units scaled to 27 decimals
    // function debtOfExact(address account) external view returns (uint);

    // /// @notice Retrieves the current interest rate for an asset
    // /// @return The interest rate in yield-per-second, scaled by 10**27
    // function interestRate() external view returns (int96);

    // /// @notice Retrieves the current interest rate accumulator for an asset
    // /// @return An opaque accumulator that increases as interest is accrued
    // function interestAccumulator() external view returns (uint);

    // /// @notice Address of the risk manager
    // function riskManager() external view returns (address);

    // /// @notice Address of the DToken
    // function dToken() external view returns (address);

    // /// @notice Address of CreditVaultConnector contract
    // function getCVC() external view returns (address);



    // /// @notice Transfer underlying tokens from the Euler pool to the sender, and increase sender's dTokens
    // /// @param assets In underlying units (use max uint for all available tokens)
    // /// @param receiver Account receiving the borrowed tokens
    // function borrow(uint assets, address receiver) external;

    // /// @notice Transfer underlying tokens from the sender to the Euler pool, and decrease receiver's dTokens
    // /// @param assets In underlying units (use max uint256 for full debt owed)
    // /// @param receiver Account holding the debt to be repaid. Zero address for authenticated acount.
    // function repay(uint assets, address receiver) external;

    // /// @notice Mint shares and a corresponding amount of dTokens ("self-borrow")
    // /// @param assets In underlying units
    // /// @param collateralReceiver Account to receive the created shares.
    // /// @return Amount of shares created
    // function wind(uint assets, address collateralReceiver) external returns (uint);

    // /// @notice Pay off dToken liability with shares ("self-repay")
    // /// @param assets In underlying units (use max uint to repay the debt in full or up to the available underlying balance)
    // /// @param debtFrom Account to remove debt from by burning sender's shares.
    // /// @return Amount of shares burned
    // function unwind(uint assets, address debtFrom) external returns (uint);

    // function pullDebt(uint assets, address from) external;

    // /// @notice Request a flash-loan. A onFlashLoan() callback in msg.sender will be invoked, which must repay the loan to the main Euler address prior to returning.
    // /// @param assets In underlying units
    // /// @param data Passed through to the onFlashLoan() callback, so contracts don't need to store transient data in storage
    // function flashLoan(uint assets, bytes calldata data) external;

    // // AUXILIARY

    // /// @notice Updates interest accumulator and totalBorrows, credits reserves, re-targets interest rate, and logs asset status
    // function touch() external;

    // /// @notice Donate eTokens to the reserves
    // /// @param shares In internal book-keeping units (as returned from balanceOf).
    // function donateToReserves(uint shares) external;

    // function releaseController() external;

    // function checkAccountStatus(address account, address[] calldata collaterals) external returns (bytes4);

    function checkVaultStatus() external returns (bytes4);
}

interface ILiquidation {
    // /// @notice Checks to see if a liquidation would be profitable, without actually doing anything
    // /// @param liquidator Address that will initiate the liquidation
    // /// @param violator Address that may be in collateral violation
    // /// @param collateral Market from which the token is to be seized
    // /// @return maxRepayAssets Max amount of debt that can be repaid, in asset decimals
    // /// @return maxYieldBalance Yield in collateral corresponding to max allowed amount of debt to be repaid, in collateral balance (shares for vaults)
    // function checkLiquidation(address liquidator, address violator, address collateral) external view returns (uint maxRepayAssets, uint maxYieldBalance);

    // /// @notice Attempts to perform a liquidation
    // /// @param violator Address that may be in collateral violation
    // /// @param collateral Market from which the token is to be seized
    // /// @param repayAssets The amount of underlying DTokens to be transferred from violator to sender, in units of asset
    // /// @param minYieldAssetsOrBalance The minimum acceptable amount of collateral to be transferred from violator to sender, in asset units for internal collaterals, in balance for external
    // function liquidate(address violator, address collateral, uint repayAssets, uint minYieldAssetsOrBalance) external;
}

interface IAdmin {
    // /// @notice Balance of the fees accumulator, in internal book-keeping units (non-increasing)
    // function feesBalance() external view returns (uint);

    // /// @notice Balance of the fees accumulator, in underlying units (increases as interest is earned)
    // function feesBalanceUnderlying() external view returns (uint);

    // /// @notice Retrieves the interest fee in effect for a market
    // /// @return Amount of interest that is redirected as a fee, as a fraction scaled by INTEREST_FEE_SCALE (4e9)
    // function interestFee() external view returns (uint16);

    // /// @notice Retrieves the protocol fee share
    // /// @return A percentage share of fees accrued belonging to the protocol. In wad scale (1e18)
    // function protocolFeeShare() external view returns (uint);

    // function convertFees() external;
}

interface IEVault is IERC20, IERC4626, IBorrowing, ILiquidation, IAdmin {
    function initialize() external;
}
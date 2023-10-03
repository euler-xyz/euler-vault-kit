// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./base/BaseLogic.sol";
import "../../EVaultFactory/EVaultFactory.sol";
import "../DToken.sol";
import { IERC20, IERC4626, IBorrowing, ILiquidation, IAdmin } from "../IEVault.sol";



abstract contract ERC20Module is IERC20, BaseLogic {
    /// @notice Pool name, ie "Euler Pool: DAI"
    function name() external view virtual returns (string memory) {
        (address asset_,) = proxyMetadata();

        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = asset_.staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) revertBytes(data);
        return string.concat("Euler Pool: ", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    /// @notice Pool symbol, ie "eDAI"
    function symbol() external view virtual returns (string memory) {
        (address asset_,) = proxyMetadata();

        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = asset_.staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) revertBytes(data);
        return string.concat("e", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    /// @notice Decimals, same as underlying asset
    function decimals() external view virtual returns (uint8) {
        (address asset_,) = proxyMetadata();

        return IERC20(asset_).decimals();
    }

    /// @notice Sum of all share balances (non-increasing)
    function totalSupply() external view virtual returns (uint) {
        return loadMarketCacheRO().totalBalances;
    }

    /// @notice Balance of a particular account, in internal book-keeping units (non-increasing)
    function balanceOf(address account) external view virtual returns (uint) {
        return marketStorage.users[account].balance;
    }

    /// @notice Retrieve the current allowance
    /// @param holder The account holding the assets
    /// @param spender Trusted address
    function allowance(address holder, address spender) external view virtual returns (uint) {
        return marketStorage.eVaultAllowance[holder][spender];
    }




    /// @notice Transfer eVaults to another address (from sub-account 0)
    /// @param to Recipient account
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transfer(address to, uint amount) external virtual reentrantOK returns (bool) {
        return transferFrom(address(0), to, amount);
    }

    /// @notice Transfer the full eVault balance of an address to another
    /// @param from This address must've approved the to address, or be a sub-account of msg.sender
    /// @param to Recipient account
    function transferFromMax(address from, address to) external virtual reentrantOK returns (bool) {
        return transferFrom(from, to, marketStorage.users[from].balance);
    }

    /// @notice Transfer eVaults from one address to another
    /// @param from This address must've approved the to address, or be a sub-account of msg.sender
    /// @param to Recipient account
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transferFrom(address from, address to, uint amount) public virtual nonReentrantWithChecks returns (bool) {
        address account = CVCAuthenticate();
        if (from == address(0)) from = account;
        return _transferFrom(account, loadMarketCache(), from, to, amount);
    }
    function _transferFrom(address account, MarketCache memory marketCache, address from, address to, uint amount) private 
        lock(from, marketCache, PAUSETYPE__WITHDRAW | PAUSETYPE__DEPOSIT)
        returns (bool) 
    {
        if (from == to) revert E_SelfTransfer();

        emit RequestTransferEVault(from, to, amount);

        if (amount == 0) return true;

        decreaseAllowance(from, account, amount);
        transferBalance(from, to, amount);

        return true;
    }

    /// @notice Allow spender to access an amount of your eVaults
    /// @param spender Trusted address
    /// @param amount Use max uint for "infinite" allowance
    function approve(address spender, uint amount) external virtual reentrantOK returns (bool) {
        address account = CVCAuthenticate();

        if (spender == account) revert E_SelfApproval();

        marketStorage.eVaultAllowance[account][spender] = amount;
        emit Approval(account, spender, amount);

        return true;
    }
}
contract ERC20 is ERC20Module {
    constructor(address factory, address cvc) BaseLogic(factory, cvc) {}
}






abstract contract ERC4626Module is IERC4626, BaseLogic {
    /// @notice Vault underlying asset
    function asset() external view virtual returns (address) {
        (address asset_,) = proxyMetadata();
        return asset_;
    }

    /// @notice Total amount of managed assets
    function totalAssets() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        // TODO double check this: in V1 totalSupplyUnderlying was converted from totalSupply.
        // Now without initial shares balance, tokens transferred directly to vault would not be shown in conversion from 0.
        // See "market activation with pre-existing pool balance" test
        // The first depositor gets all the assets, but must deposit more than existing balance
        // return sharesToAssets(marketCache, marketCache.totalBalances);
        return marketCache.poolSize + (marketCache.totalBorrows / INTERNAL_DEBT_PRECISION);
    }

    /// @notice Calculate amount of assets corresponding to the requested shares amount
    function convertToAssets(uint shares) public view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return sharesToAssets(marketCache, shares);
    }

    /// @notice Calculate amount of share corresponding to the requested assets amount
    function convertToShares(uint assets) public view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return assetsToShares(marketCache, assets);
        // return assetsToShares(marketCache, validateExternalAmount(assets));
    }

    /// @notice Fetch the maximum amount of assets a user can deposit
    function maxDeposit(address) external view virtual returns (uint) {
        return MAX_SANE_AMOUNT; // TODO
    }

    /// @notice Calculate an amount of shares that would be created by depositing assets
    /// @param assets Amount of assets deposited
    /// @return Amount of shares received
    function previewDeposit(uint assets) external view virtual returns (uint) {
        return convertToShares(assets);
    }

    /// @notice Fetch the maximum amount of shares a user can mint
    function maxMint(address) external view virtual returns (uint) {
        return convertToShares(MAX_SANE_AMOUNT); // TODO
    }

    /// @notice Calculate an amount of assets that would be required to mint requested amount of shares
    /// @param shares Amount of shares to be minted
    /// @return Required amount of assets
    function previewMint(uint shares) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return sharesToAssetsRoundUp(marketCache, shares);
    }

    /// @notice Fetch the maximum amount of assets a user is allowed to withdraw
    /// @param owner Account holding the shares
    /// @return The maximum amount of assets the owner is allowed to withdraw
    function maxWithdraw(address owner) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return sharesToAssets(marketCache, marketStorage.users[owner].balance);
    }

    /// @notice Calculate the amount of shares that will be burned when withdrawing requested amount of assets
    /// @param assets Amount of assets withdrawn
    /// @return Amount of shares burned
    function previewWithdraw(uint assets) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return assetsToSharesRoundUp(marketCache, assets);
        // return assetsToSharesRoundUp(marketCache, validateExternalAmount(assets));
    }

    /// @notice Fetch the maximum amount of shares a user is allowed to redeem for assets
    /// @param owner Account holding the shares
    /// @return The maximum amount of shares the owner is allowed to redeem
    function maxRedeem(address owner) external view virtual returns (uint) {
        return marketStorage.users[owner].balance;
    }

    /// @notice Calculate the amount of assets that will be transferred when redeeming requested amount of shares
    /// @param shares Amount of shares redeemed
    /// @return Amount of assets transferred
    function previewRedeem(uint shares) external view virtual returns (uint) {
        return convertToAssets(shares);
    }



    /// @notice Transfer requested amount of underlying tokens from sender to the vault pool in return for shares
    /// @param assets In underlying units (use max uint for full underlying token balance)
    /// @param receiver An account to receive the shares
    /// @return shares Amount of shares minted
    function deposit(uint assets, address receiver) external virtual nonReentrantWithChecks returns (uint shares) {
        shares = _deposit(CVCAuthenticate(), loadMarketCache(), assets, receiver);
    }
    function _deposit(address account, MarketCache memory marketCache, uint assets, address receiver) private
        lock(address(0), marketCache, PAUSETYPE__DEPOSIT)
        returns (uint shares)
    {
        if (receiver == address(0)) receiver = account;

        emit RequestDeposit(account, receiver, assets);


        if (assets == type(uint).max) {
            assets = callBalanceOf(marketCache, account);
        }
        uint assetsTransferred = pullTokens(marketCache, account, assets);
        // uint assetsTransferred = pullTokens(marketCache, account, validateExternalAmount(assets));

        // pullTokens() updates poolSize in the cache, but we need the poolSize before the deposit to determine
        // the internal amount so temporarily reduce it by the amountTransferred (which is size checked within
        // pullTokens()). We can't compute this value before the pull because we don't know how much we'll
        // actually receive (the token might be deflationary).

        unchecked {
            marketCache.poolSize -= assetsTransferred;
            shares = assetsToShares(marketCache, assetsTransferred);
            marketCache.poolSize += assetsTransferred;
        }

        if (shares == 0) revert E_ZeroShares();

        increaseBalance(marketCache, receiver, shares);

        emit Deposit(account, receiver, assetsTransferred, shares);
    }

    /// @notice Transfer underlying tokens from sender to the vault pool in return for requested amount of shares
    /// @param shares Amount of share to be minted
    /// @param receiver An account to receive the shares
    /// @return assets Amount of assets deposited
    function mint(uint shares, address receiver) external virtual nonReentrantWithChecks returns (uint assets) {
        assets = _mint(CVCAuthenticate(), loadMarketCache(), shares, receiver);
    }
    function _mint(address account, MarketCache memory marketCache, uint shares, address receiver) private
        lock(address(0), marketCache, PAUSETYPE__DEPOSIT)
        returns (uint)
    {
        if (receiver == address(0)) receiver = account;

        emit RequestMint(account, receiver, shares);

        uint assets;
        if (shares == type(uint).max) {
            // assets = validateExternalAmount(callBalanceOf(marketCache, account));
            assets = callBalanceOf(marketCache, account);
            shares = assetsToShares(marketCache, assets);
            if (shares == 0) revert E_ZeroShares();
        } else {
            // assets = validateExternalAmount(sharesToAssetsRoundUp(marketCache, shares));
            assets = sharesToAssetsRoundUp(marketCache, shares);
        }

        uint assetsTransferred = pullTokens(marketCache, account, assets);

        if (assetsTransferred != assets) revert E_TransferAmountMismatch();
        // TODO finalize deposit?
        increaseBalance(marketCache, receiver, shares);
        emit Deposit(account, receiver, assetsTransferred, shares);

        return assetsTransferred;
    }


    /// @notice Transfer requested amount of underlying tokens from the vault and decrease account's shares
    /// @param assets In underlying units (use max uint for full pool balance)
    /// @param receiver Account to receive the withdrawn assets
    /// @param owner Account holding the shares to burn
    /// @return shares Amount of shares burned
    function withdraw(uint assets, address receiver, address owner) external virtual nonReentrantWithChecks returns (uint shares) {
        shares = _withdraw(CVCAuthenticate(), loadMarketCache(), assets, receiver, owner);
    }
    function _withdraw(address account, MarketCache memory marketCache, uint assets, address receiver, address owner) private
        lock(owner, marketCache, PAUSETYPE__WITHDRAW)
        returns (uint shares)
    {
        if (receiver == address(0)) receiver = getAccountOwner(owner);

        emit RequestWithdraw(account, receiver, owner, assets);

        // TODO withdrawAmounts needed?
        (assets, shares) = withdrawAmounts(marketCache, owner, assets);
        // if requested amount is MAX_UINT, assets are rounded down
        if (assets == 0 && shares > 0) revert E_ZeroAssets();

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);
    }

    /// @notice Burn requested shares and transfer corresponding underlying tokens from the vault to the receiver
    /// @param shares Amount of shares to burn
    /// @param receiver Account to receive the withdrawn assets
    /// @param owner Account holding the shares to burn.
    /// @return assets Amount of assets transferred
    function redeem(uint shares, address receiver, address owner) external virtual nonReentrantWithChecks returns (uint assets) {
        assets = _redeem(CVCAuthenticate(), loadMarketCache(), shares, receiver, owner);
    }
    function _redeem(address account, MarketCache memory marketCache, uint shares, address receiver, address owner) private
        lock(owner, marketCache, PAUSETYPE__WITHDRAW) 
        returns (uint assets)
    {
        if (receiver == address(0)) receiver = getAccountOwner(owner);

        emit RequestRedeem(account, receiver, owner, shares);

        if (shares == type(uint).max) {
            shares = marketStorage.users[owner].balance;
        }

        assets = sharesToAssets(marketCache, shares);
        // assets = validateExternalAmount(sharesToAssets(marketCache, shares));
        if (assets == 0) revert E_ZeroAssets();

        finalizeWithdraw(marketCache, assets, shares, account, receiver, owner);
    }

    function finalizeWithdraw(MarketCache memory marketCache, uint assets, uint shares, address sender, address receiver, address owner) private {
        if (marketCache.poolSize < assets) revert E_InsufficientPoolSize();

        decreaseAllowance(owner, sender, shares);
        // TODO check effect before interaction - OZ comment
        decreaseBalance(marketCache, owner, shares);
        pushTokens(marketCache, receiver, assets);

        emit Withdraw(sender, receiver, owner, assets, shares);
    }
}
contract ERC4626 is ERC4626Module {
    constructor(address factory, address cvc) BaseLogic(factory, cvc) {}
}







/// @notice Definition of callback method that flashLoan will invoke on your contract
interface IFlashLoan {
    function onFlashLoan(bytes memory data) external;
}
abstract contract BorrowingModule is IBorrowing, BaseLogic {

    /// @notice Sum of all outstanding debts, in underlying units (increases as interest is accrued)
    function totalBorrows() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return marketCache.totalBorrows / INTERNAL_DEBT_PRECISION;
    }

    function totalBorrowsExact() external view virtual returns (uint) {
        return loadMarketCacheRO().totalBorrows;
    }

    /// @notice Debt owed by a particular account, in underlying units
    function debtOf(address account) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return getCurrentOwed(marketCache, account);
    }

    /// @notice Debt owed by a particular account, in underlying units scaled up by 1e9
    function debtOfExact(address account) external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return getCurrentOwedExact(marketCache, account, marketStorage.users[account].owed);
    }

    /// @notice Retrieves the current interest rate for an asset
    /// @return The interest rate in yield-per-second, scaled by 10**27
    function interestRate() external view virtual returns (int96) {
        return marketStorage.interestRate;
    }

    /// @notice Retrieves the current interest rate accumulator for an asset
    /// @return An opaque accumulator that increases as interest is accrued
    function interestAccumulator() external view virtual returns (uint) {
        return loadMarketCacheRO().interestAccumulator;
    }

    /// @notice Retrieves the address of the risk manager configured for the pool
    /// @return Address of risk manager
    function riskManager() external view virtual returns (address) {
        (, address riskManagerAddress) = proxyMetadata();
        return riskManagerAddress;
    }

    function dToken() external view virtual returns (address) {
        return calculateDTokenAddress();
    }

    function getCVC() external view virtual returns (address) {
        return address(cvc);
    }


    /// @notice Transfer underlying tokens from the Euler pool to the sender, and increase sender's dTokens
    /// @param assets In underlying units (use max uint for all available tokens)
    /// @param receiver Account receiving the borrowed tokens
    function borrow(uint assets, address receiver) external virtual nonReentrantWithChecks {
        _borrow(CVCAuthenticateForBorrow(), loadMarketCache(), assets, receiver);
    }
    function _borrow(address account, MarketCache memory marketCache, uint assets, address receiver) private
        lock(account, marketCache, PAUSETYPE__BORROW)
    {
        if (receiver == address(0)) receiver = getAccountOwner(account);

        emit RequestBorrow(account, receiver, assets);

        if (assets == type(uint).max) {
            assets = marketCache.poolSize;
        } 
        // else {
        //     assets = validateExternalAmount(assets);
        // }
        if (assets > marketCache.poolSize) revert E_InsufficientPoolSize();

        pushTokens(marketCache, receiver, assets);
        // TODO effects first?
        increaseBorrow(marketCache, account, assets);
    }

    /// @notice Transfer underlying tokens from the sender to the Euler pool, and decrease receiver's dTokens
    /// @param assets In underlying units (use max uint256 for full debt owed)
    /// @param receiver Account holding the debt to be repaid. Zero address for authenticated acount.
    function repay(uint assets, address receiver) external virtual nonReentrantWithChecks {
        _repay(CVCAuthenticate(), loadMarketCache(), assets, receiver);
    }
    function _repay(address account, MarketCache memory marketCache, uint assets, address receiver) private
        lock(address(0), marketCache, PAUSETYPE__REPAY)
    {
        if (receiver == address(0)) receiver = account;

        if (!isControllerEnabled(receiver, address(this))) revert E_ControllerDisabled();

        emit RequestRepay(account, receiver, assets);

        // if (assets != type(uint).max) {
        //     assets = validateExternalAmount(assets);
        // }

        uint owed = getCurrentOwed(marketCache, receiver);
        if (owed == 0) return;
        if (assets > owed) assets = owed;

        assets = pullTokens(marketCache, account, assets);

        decreaseBorrow(marketCache, receiver, assets);
    }

    /// @notice Mint shares and a corresponding amount of dTokens ("self-borrow")
    /// @param assets In underlying units
    /// @param collateralReceiver Account to receive the created shares.
    /// @return shares Amount of shares minted
    function wind(uint assets, address collateralReceiver) external virtual nonReentrantWithChecks returns (uint shares) {
        shares = _wind(CVCAuthenticateForBorrow(), loadMarketCache(), assets, collateralReceiver);
    }
    function _wind(address account, MarketCache memory marketCache, uint assets, address collateralReceiver) private
        lock(account, marketCache, PAUSETYPE__WIND)
        returns (uint shares)
    {
        if (collateralReceiver == address(0)) collateralReceiver = account;

        emit RequestWind(account, collateralReceiver, assets);

        shares = assetsToSharesRoundUp(marketCache, assets);
        // shares = assetsToSharesRoundUp(marketCache, validateExternalAmount(assets));
        assets = sharesToAssets(marketCache, shares);

        // Mint EVaults
        increaseBalance(marketCache, collateralReceiver, shares);

        // Mint DTokens
        increaseBorrow(marketCache, account, assets);
    }

    /// @notice Pay off dToken liability with shares ("self-repay")
    /// @param assets In underlying units (use max uint to repay the debt in full or up to the available underlying balance)
    /// @param debtFrom Account to remove debt from by burning sender's shares.
    /// @return shares Amount of shares burned
    function unwind(uint assets, address debtFrom) external virtual nonReentrantWithChecks returns (uint shares) {
        shares = _unwind(CVCAuthenticateForBorrow(), loadMarketCache(), assets, debtFrom);
    }
    function _unwind(address account, MarketCache memory marketCache, uint assets, address debtFrom) private
        lock(account, marketCache, PAUSETYPE__UNWIND)
        returns (uint shares) 
    {
        if (debtFrom == address(0)) debtFrom = account;

        emit RequestUnwind(account, debtFrom, assets);

        uint owed = getCurrentOwed(marketCache, debtFrom);
        if (owed == 0) return 0;

        (assets, shares) = withdrawAmounts(marketCache, account, assets);

        if (assets > owed) {
            assets = owed;
            shares = assetsToSharesRoundUp(marketCache, assets);
        }

        // Burn EVaults

        decreaseBalance(marketCache, account, shares);

        // Burn DTokens

        decreaseBorrow(marketCache, debtFrom, assets);
    }

    function pullDebt(uint assets, address from) external nonReentrantWithChecks virtual returns (bool) {
        return _pullDebt(CVCAuthenticateForBorrow(), loadMarketCache(), assets, from);
    }
    function _pullDebt(address account, MarketCache memory marketCache, uint assets, address from) private
        lock(account, marketCache, PAUSETYPE__BORROW | PAUSETYPE__REPAY)
        returns (bool)
    {
        if (from == account) revert E_SelfTransfer();

        emit RequestPullDebt(from, account, assets);

        assets = assets == type(uint).max
            ? getCurrentOwed(marketCache, from)
            : validateExternalAmount(assets);

        if (assets != 0) transferBorrow(marketCache, from, account, assets);

        return true;
    }

    /// @notice Request a flash-loan. A onFlashLoan() callback in msg.sender will be invoked, which must repay the loan to the main Euler address prior to returning.
    /// @param assets In underlying units
    /// @param data Passed through to the onFlashLoan() callback, so contracts don't need to store transient data in storage
    function flashLoan(uint assets, bytes calldata data) external virtual nonReentrant {
        (address asset_,) = proxyMetadata();
        address account = CVCAuthenticate();

        uint origBalance = IERC20(asset_).balanceOf(address(this));

        Utils.safeTransfer(asset_, account, assets);

        IFlashLoan(account).onFlashLoan(data);

        if (IERC20(asset_).balanceOf(address(this)) < origBalance) revert E_FlashLoanNotRepaid();
    }

    /// @notice Updates interest accumulator and totalBorrows, credits reserves, re-targets interest rate, and logs asset status
    function touch() external virtual nonReentrant {
        MarketCache memory marketCache = loadMarketCache();
        marketSnapshot(PAUSETYPE__NONE, marketCache);

        checkMarketStatus();

        logMarketStatus(marketCache);
    }

    /// @notice Donate eVaults to the reserves
    /// @param shares In internal book-keeping units (as returned from balanceOf).
    function donateToReserves(uint shares) external virtual nonReentrant {
        // (address market, MarketStorage storage marketStorage, address msgSender) = CALLER();
        // MarketCache memory marketCache = loadMarketCache(market, marketStorage);
        // marketSnapshot(market, PAUSETYPE__WITHDRAW, marketCache);

        // address account = CVCAuthenticate(msgSender);

        // emit RequestDonate(account, shares);

        // uint origBalance = marketStorage.users[account].balance;
        // uint newBalance;

        // if (shares == type(uint).max) {
        //     shares = origBalance;
        //     newBalance = 0;
        // } else {
        //     if (origBalance < shares) revert E_InsufficientBalance();
        //     unchecked { newBalance = origBalance - shares; }
        // }

        // marketStorage.users[account].balance = encodeAmount(newBalance);
        // marketStorage.feesBalance = marketCache.feesBalance = encodeSmallAmount(marketCache.feesBalance + shares);

        // emit DecreaseBalance(marketCache.market, account, shares);
        // emitViaProxy_Transfer(market, account, address(0), shares);

        // checkAccountLiquidity(account);
        // logMarketStatus(marketCache);
        // checkMarketStatus(market);
    }

   // TODO not necessary if decreaseDebt works correctly
    function releaseController() external virtual nonReentrant {
        address account = CVCAuthenticate();

        if (marketStorage.users[account].owed > 0) revert E_OutstandingDebt();

        releaseControllerInternal(account);
    }

    function checkAccountStatus(address account, address[] calldata collaterals) external virtual reentrantOK returns (bool, bytes memory) {
        (
            address riskManagerAddress,
            IRiskManager.MarketAssets memory liabilityBalance,
            IRiskManager.MarketAssets[] memory collateralBalances
        ) = getLiquidityPayload(account, collaterals);

        bool isValid = IRiskManager(riskManagerAddress).checkLiquidity(account, collateralBalances, liabilityBalance);

        return (isValid, "");
    }

    function checkVaultStatus() external virtual reentrantOK returns (bool, bytes memory) {
        if (msg.sender != address(cvc)) return (false, "e/invalid-caller");

        MarketCache memory marketCache = internalloadMarketCacheRO();
        updateInterestParams(marketCache);

        MarketSnapshot memory currentSnapshot = getMarketSnapshot(0, marketCache);
        MarketSnapshot memory oldSnapshot = marketStorage.marketSnapshot;
        delete marketStorage.marketSnapshot.performedOperations;

        if (oldSnapshot.performedOperations == 0) return (false, "e/snaphot-tampered");
        if (oldSnapshot.interestAccumulator != currentSnapshot.interestAccumulator) return (false, "e/interest-accumulator-invariant");

        int totalDelta;

        // TODO can the invariant be broken with exchange rates and decimals? Total balances are converted. Exchange rate < 1 will break totalDelta <= 1?
        // TODO rename total balances to totalBalancesInAssets?
        unchecked {
            int poolSizeDelta = int(uint(currentSnapshot.poolSize)) - int(uint(oldSnapshot.poolSize));
            int totalBalancesDelta = int(uint(currentSnapshot.totalBalances)) - int(uint(oldSnapshot.totalBalances));
            int totalBorrowsDelta = int(uint(currentSnapshot.totalBorrows)) - int(uint(oldSnapshot.totalBorrows));
            totalDelta = poolSizeDelta + totalBorrowsDelta - totalBalancesDelta;
            totalDelta = totalDelta > 0 ? totalDelta : -totalDelta;
        }
        if (totalDelta > 1) return (false, "e/balances-invariant");

        return IRiskManager(marketCache.riskManager)
            .checkMarketStatus(
                oldSnapshot.performedOperations, 
                IRiskManager.Snapshot({
                    totalBalances: oldSnapshot.totalBalances,
                    totalBorrows: oldSnapshot.totalBorrows
                }),
                IRiskManager.Snapshot({
                    totalBalances: currentSnapshot.totalBalances,
                    totalBorrows: currentSnapshot.totalBorrows
                })
            );
    }
}
contract Borrowing is BorrowingModule {
    constructor(address factory, address cvc) BaseLogic(factory, cvc) {}
}






abstract contract LiquidationModule is ILiquidation, BaseLogic {
    struct LiquidationLocals {
        address liquidator;
        address violator;
        address collateral;

        uint repayAssets;
        uint feeAssets;
        uint yieldBalance;

        uint repayPreFeesAssets;

        address riskManager;
        bytes accountSnapshot;
    }

    /// @notice Checks to see if a liquidation would be profitable, without actually doing anything
    /// @param liquidator Address that will initiate the liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Market from which the token is to be seized
    /// @return maxRepay Max amount of debt that can be repaid, in asset decimals
    /// @return maxYield Yield in collateral corresponding to max allowed amount of debt to be repaid, in collateral balance (shares for vaults)
    function checkLiquidation(address liquidator, address violator, address collateral) external view virtual returns (uint maxRepay, uint maxYield) {
        if (marketStorage.reentrancyLock != REENTRANCYLOCK__UNLOCKED) revert E_Reentrancy();

        LiquidationLocals memory liqLocs;

        liqLocs.liquidator = liquidator;
        liqLocs.violator = violator;
        liqLocs.collateral = collateral;

        getLiqOpp(liqLocs, type(uint).max);

        maxRepay = liqLocs.repayAssets + liqLocs.feeAssets;
        maxYield = liqLocs.yieldBalance;
    }

    /// @notice Attempts to perform a liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Market from which the token is to be seized
    /// @param repayAssets The amount of underlying DTokens to be transferred from violator to sender, in units of asset
    /// @param minYieldBalance The minimum acceptable amount of collateral to be transferred from violator to sender, in balance (shares for collaerals which are vaults)
    function liquidate(address violator, address collateral, uint repayAssets, uint minYieldBalance) external virtual nonReentrantWithChecks {
        _liquidate(CVCAuthenticateForBorrow(), loadMarketCache(), violator, collateral, repayAssets, minYieldBalance);
    }
    function _liquidate(address account, MarketCache memory marketCache, address violator, address collateral, uint repayAssets, uint minYieldBalance) private
        // TODO should it check market? Add pause type?
        lock(account, marketCache, PAUSETYPE__NONE)
    {
        if (isAccountStatusCheckDeferred(violator)) revert E_ViolatorLiquidityDeferred();

        emit RequestLiquidate(account, violator, collateral, address(this), repayAssets, minYieldBalance);

        // Calculate repay, fee and yield

        LiquidationLocals memory liqLocs;

        liqLocs.liquidator = account;
        liqLocs.violator = violator;
        liqLocs.collateral = collateral;

        getLiqOpp(liqLocs, repayAssets);

        executeLiquidation(marketCache, liqLocs, repayAssets, minYieldBalance);
    }

    function executeLiquidation(MarketCache memory marketCache, LiquidationLocals memory liqLocs, uint desiredRepayAssets, uint minYieldBalance) private {
        if (desiredRepayAssets > liqLocs.repayAssets + liqLocs.feeAssets) revert E_ExcessiveRepayAmount();
        if (minYieldBalance > liqLocs.yieldBalance) revert E_MinYield();

        // This check also prevents triggering liquidation on collaterals not recognized by risk manager.
        if (liqLocs.repayAssets == 0) return;

        // Handle repay and fee

        // Liquidator takes on violator's debt:
        transferBorrow(marketCache, liqLocs.violator, liqLocs.liquidator, validateExternalAmount(liqLocs.repayAssets));

        // Extra debt is minted and assigned to liquidator to cover the fee:
        increaseBorrow(marketCache, liqLocs.liquidator, validateExternalAmount(liqLocs.feeAssets));


        // The underlying's fees balance is credited to compensate for this extra debt:
        {
            uint poolAssets = marketCache.poolSize + (marketCache.totalBorrows / INTERNAL_DEBT_PRECISION);
            uint newTotalBalances = poolAssets * marketCache.totalBalances / (poolAssets - liqLocs.feeAssets);
            increaseFees(marketCache, newTotalBalances - marketCache.totalBalances);
        }

        // Handle yield

        if (liqLocs.collateral != address(this)) {
            enforceExternalCollateralTransfer(liqLocs.collateral, liqLocs.yieldBalance, liqLocs.violator, liqLocs.liquidator);

            verifyLiquidation(liqLocs);
            // Remove scheduled health check for the violator's account. This operation is safe, because:
            // 1. `liquidate` function is enforcing that the violator is not in deferred checks state,
            //    therefore there were no prior batch operations that could have registered a health check,
            //    and if the check is present now, it must have been triggered by the enforced transfer.
            // 2. `verifyLiquidation` function is comparing the whole account state before and after yield transfer
            //    to make sure there were no side effects, effectively performing an equivalent of the health check immediately.
            // 3. Any additional operations on violator's account in a batch will register the health check again, and it
            //    will be executed normally at the end of the batch.
            // If the liquidation is not executed as a part of a batch, then the health check on yield transfer is not deferred,
            // but executed immediately, and it's not possible to forgive it. In consequence, EVault.checkAccountStatus will
            // re-enter and revert. Therefore, liquidations must be performed through a CVC batch.
            forgiveAccountStatusCheck(liqLocs.violator);
        } else {
            transferBalance(liqLocs.violator, liqLocs.liquidator, liqLocs.yieldBalance);
        }

        emitLiquidationLog(liqLocs);
    }


    function verifyLiquidation(LiquidationLocals memory liqLocs) private view {
        (
            ,
            IRiskManager.MarketAssets memory liability,
            IRiskManager.MarketAssets[] memory collaterals
        ) = getLiquidityPayload(liqLocs.violator, getCollaterals(liqLocs.violator));

        bool isValid = IRiskManager(liqLocs.riskManager).verifyLiquidation(
            liqLocs.liquidator,
            liqLocs.violator,
            liqLocs.collateral,
            liqLocs.yieldBalance,
            liqLocs.repayAssets,
            collaterals,
            liability,
            liqLocs.accountSnapshot
        );

        if (!isValid) revert E_InvalidLiquidationState();
    }

    function emitLiquidationLog(LiquidationLocals memory liqLocs) private {
        emit Liquidate(liqLocs.liquidator, liqLocs.violator, address(this), liqLocs.collateral, liqLocs.repayAssets, liqLocs.yieldBalance, liqLocs.feeAssets);
    }

    function getLiqOpp(LiquidationLocals memory liqLocs, uint desiredRepay) private view {
        if (liqLocs.violator == liqLocs.liquidator) revert E_SelfLiquidation();
        if (getController(liqLocs.violator) != address(this)) revert E_ViolatorNotEnteredController();
        if (!isEnteredCollateral(liqLocs.violator, liqLocs.collateral)) revert E_ViolatorNotEnteredCollateral();
        IRiskManager.MarketAssets memory liability;
        IRiskManager.MarketAssets[] memory collaterals;
        (
            liqLocs.riskManager,
            liability,
            collaterals
        ) = getLiquidityPayload(liqLocs.violator, getCollaterals(liqLocs.violator));
        if (!liability.assetsSet) revert E_InvalidLiability();

        // violator has no liabilities
        if (liability.assets == 0) return;

        (liqLocs.repayAssets, liqLocs.yieldBalance, liqLocs.feeAssets, liqLocs.accountSnapshot) = IRiskManager(liqLocs.riskManager).calculateLiquidation(liqLocs.liquidator, liqLocs.violator, liqLocs.collateral, collaterals, liability, desiredRepay);

        if (liqLocs.collateral == address(this)) {
            // TODO pass down market cache from top level
            MarketCache memory marketCache = internalloadMarketCacheRO();
            // liqLocs.yieldBalance = assetsToSharesRoundUp(marketCache, validateExternalAmount(liqLocs.yieldBalance));
            liqLocs.yieldBalance = assetsToSharesRoundUp(marketCache, liqLocs.yieldBalance);
        }
    }
}
contract Liquidation is LiquidationModule {
    constructor(address factory, address cvc) BaseLogic(factory, cvc) {}
}




abstract contract AdminModule is IAdmin, BaseLogic {
    /// @notice Balance of the fees accumulator, in internal book-keeping units (non-increasing)
    function feesBalance() external view virtual returns (uint) {
        return loadMarketCacheRO().feesBalance;
    }

    /// @notice Balance of the fees accumulator, in underlying units (increases as interest is earned)
    function feesBalanceUnderlying() external view virtual returns (uint) {
        MarketCache memory marketCache = loadMarketCacheRO();

        return sharesToAssets(marketCache, marketCache.feesBalance);
    }

    /// @notice Retrieves the interest fee in effect for a market
    /// @return Amount of interest that is redirected as a fee, as a fraction scaled by INTEREST_FEE_SCALE (6e4)
    function interestFee() external view virtual returns (uint16) {
        return marketStorage.interestFee;
    }

    /// @notice Retrieves the protocol fee share
    /// @return A percentage share of fees accrued belonging to the protocol. In wad scale (1e18)
    function protocolFeeShare() external view virtual returns (uint) {
        return PROTOCOL_FEE_SHARE;
    }

    function convertFees() external virtual nonReentrantWithChecks {
        _convertFees(CVCAuthenticate(), loadMarketCache());
    }
    function _convertFees(address account, MarketCache memory marketCache) private
        lock(address(0), marketCache, PAUSETYPE__NONE)
    {
        if (account != marketCache.riskManager && account != EVaultFactory(factory).getGovernorAdmin()) revert E_Unauthorized();

        emit RequestConvertFees(account);

        // Decrease totalBalances because increaseBalance will increase it by that total amount
        marketStorage.totalBalances = marketCache.totalBalances = encodeAmount(marketCache.totalBalances - marketCache.feesBalance);

        uint riskManagerShares = marketCache.feesBalance * (1e18 - PROTOCOL_FEE_SHARE) / 1e18;
        uint protocolShares = marketCache.feesBalance - riskManagerShares;
        marketStorage.feesBalance = marketCache.feesBalance = 0;

        address protocolHolder = EVaultFactory(factory).getProtocolFeesHolder();
        increaseBalance(marketCache, marketCache.riskManager, riskManagerShares);
        increaseBalance(marketCache, protocolHolder, protocolShares);

        emit ConvertFees(protocolHolder, marketCache.riskManager, sharesToAssets(marketCache, protocolShares), sharesToAssets(marketCache, riskManagerShares));
    }
}
contract Admin is AdminModule {
    constructor(address factory, address cvc) BaseLogic(factory, cvc) {}
}

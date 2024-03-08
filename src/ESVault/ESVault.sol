// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../EVault/EVault.sol";
import {IBorrowing} from "../EVault/IEVault.sol";
import "../EVault/shared/types/MarketCache.sol";
// import {Base} from "../EVault/shared/Base.sol";
import "../EVault/shared/Constants.sol";
// import "../Evault/shared/types/Types.sol";
import "../Evault/shared/Errors.sol";
import "../ESynth/IESynth.sol";

type ConfigAmount is uint16;

// Inlined because of import issues
// TODO fix this
library TypesLib {
    function toShares(uint256 amount) internal pure returns (Shares) {
        if (amount > MAX_SANE_AMOUNT) revert Errors.E_AmountTooLargeToEncode();
        return Shares.wrap(uint112(amount));
    }

    function toAssets(uint256 amount) internal pure returns (Assets) {
        if (amount > MAX_SANE_AMOUNT) revert Errors.E_AmountTooLargeToEncode();
        return Assets.wrap(uint112(amount));
    }

    function toOwed(uint256 amount) internal pure returns (Owed) {
        if (amount > MAX_SANE_DEBT_AMOUNT) revert Errors.E_DebtAmountTooLargeToEncode();
        return Owed.wrap(uint144(amount));
    }

    function toConfigAmount(uint16 amount) internal pure returns (ConfigAmount) {
        if (amount > CONFIG_SCALE) revert Errors.E_InvalidConfigAmount();
        return ConfigAmount.wrap(amount);
    }
}

contract ESVault is EVault {
    using TypesLib for uint256;

    error NOT_SUPPORTTED();
    error NOT_SYNTH();

    address SYNTH_DEPOSIT_ADDRESS = address(uint160(uint256(keccak256("SynthDepositAddress"))));

    constructor(
        Integrations memory integrations,
        address MODULE_INITIALIZE_,
        address MODULE_TOKEN_,
        address MODULE_VAULT_,
        address MODULE_BORROWING_,
        address MODULE_LIQUIDATION_,
        address MODULE_RISKMANAGER_,
        address MODULE_BALANCE_FORWARDER_,
        address MODULE_GOVERNANCE_
    ) EVault(
        integrations,
        MODULE_INITIALIZE_,
        MODULE_TOKEN_,
        MODULE_VAULT_,
        MODULE_BORROWING_,
        MODULE_LIQUIDATION_,
        MODULE_RISKMANAGER_,
        MODULE_BALANCE_FORWARDER_,
        MODULE_GOVERNANCE_
    ) {
    }

    // ----------------- Borrowing -----------------

    /// @inheritdoc IBorrowing
    function borrow(uint256 amount, address receiver) external override nonReentrant {
        (MarketCache memory marketCache, address account) = initOperationForBorrow(OP_BORROW);

        if (receiver == address(0)) receiver = getAccountOwner(account);

        Assets assets = amount == type(uint256).max ? marketCache.cash : amount.toAssets();
        if (assets.isZero()) return;

        if (assets > marketCache.cash) revert E_InsufficientCash();

        increaseBorrow(marketCache, account, assets);

        marketStorage.cash = marketCache.cash = marketCache.cash - assets;
        IESynth(address(marketCache.asset)).mint(receiver, assets.toUint());
    }

    /// @inheritdoc IBorrowing
    function repay(uint256 amount, address receiver) external override nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_REPAY, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        uint256 owed = getCurrentOwed(marketCache, receiver).toAssetsUp().toUint();

        Assets assets = (amount > owed ? owed : amount).toAssets();
        if (assets.isZero()) return;

        IESynth(address(marketCache.asset)).burn(account, assets.toUint());
        marketStorage.cash = marketCache.cash = marketCache.cash + assets;

        decreaseBorrow(marketCache, receiver, assets);
    }

    function loop(uint256 assets, address collateralReceiver) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function deloop(uint256 assets, address debtFrom) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function flashLoan(uint256 assets, bytes calldata data) external override {
        // TODO alternative flashloan implementation which is functionaly equivalent
        revert NOT_SUPPORTTED();
    }

    // ----------------- Vault -----------------

    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function mint(uint256 shares, address receiver) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function skim(uint256 assets, address receiver) external override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    // ----------------- Governance -----------------
    function convertFees() external override {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, ACCOUNTCHECK_NONE);

        if (marketCache.accumulatedFees.isZero()) return;

        // Decrease totalShares because they are effectively withdrawn from the protocol
        marketStorage.totalShares =
            marketCache.totalShares = marketCache.totalShares - marketCache.accumulatedFees;

        (address protocolReceiver, uint256 protocolFee) = protocolConfig.feeConfig(address(this));
        address governorReceiver = marketStorage.feeReceiver;

        if (governorReceiver == address(0)) protocolFee = 1e18; // governor forfeits fees
        else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) protocolFee = MAX_PROTOCOL_FEE_SHARE;


        Shares governorShares = marketCache.accumulatedFees.mulDiv(1e18 - protocolFee, 1e18);
        Shares protocolShares = marketCache.accumulatedFees - governorShares;

        marketStorage.accumulatedFees = marketCache.accumulatedFees = Shares.wrap(0);

        Assets governorAssets = governorShares.toAssetsDown(marketCache);
        Assets protocolAssets = protocolShares.toAssetsDown(marketCache);

        // Mint synth to fee receivers
        IESynth(address(marketCache.asset)).mint(protocolReceiver, protocolAssets.toUint());
        IESynth(address(marketCache.asset)).mint(governorReceiver, governorAssets.toUint());

        emit ConvertFees(
            account,
            protocolReceiver,
            governorReceiver,
            protocolAssets.toUint(),
            governorAssets.toUint()
        );
    }

    // ----------------- Synth Specific -----------------

    function increaseCash(uint256 amount) external {
        // Update pending interest
        MarketCache memory marketCache = updateMarket();
        Assets assets = amount.toAssets();
        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        increaseBalance(marketCache, SYNTH_DEPOSIT_ADDRESS, address(0), shares, assets);
        marketStorage.cash = marketCache.cash = marketCache.cash + assets;
    }

    function decreaseCash(uint256 amount) external {
        // Update pending interest
        MarketCache memory marketCache = updateMarket();
        if(amount.toAssets() > marketCache.cash) {
            Assets assets = marketCache.cash;
            Shares shares = assets.toSharesUp(marketCache);

            decreaseBalance(marketCache, SYNTH_DEPOSIT_ADDRESS, address(0), address(0), shares, assets);
            marketStorage.cash = marketCache.cash = Assets.wrap(0);
        } else {
            Assets assets = amount.toAssets();
            Shares shares = assets.toSharesUp(marketCache);

            decreaseBalance(marketCache, SYNTH_DEPOSIT_ADDRESS, address(0), address(0), shares, assets);
            marketStorage.cash = marketCache.cash = marketCache.cash - amount.toAssets();
        }
    }

}
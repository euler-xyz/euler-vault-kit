// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../EVault/EVault.sol";
import {IBorrowing} from "../EVault/IEVault.sol";
import "../EVault/shared/types/MarketCache.sol";
// import {Base} from "../EVault/shared/Base.sol";
import "../EVault/shared/Constants.sol";
// import "../Evault/shared/types/Types.sol";
import "../Evault/shared/Errors.sol";

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

interface ISynth {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}

contract ESVault is EVault {
    using TypesLib for uint256;

    error NOT_SUPPORTTED();

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
        ISynth(address(marketCache.asset)).mint(receiver, assets.toUint());
    }

    /// @inheritdoc IBorrowing
    function repay(uint256 amount, address receiver) external override nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_REPAY, ACCOUNTCHECK_NONE);

        if (receiver == address(0)) receiver = account;

        uint256 owed = getCurrentOwed(marketCache, receiver).toAssetsUp().toUint();

        Assets assets = (amount > owed ? owed : amount).toAssets();
        if (assets.isZero()) return;

        ISynth(address(marketCache.asset)).burn(account, assets.toUint());
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

    function skim(uint256 assets, address receiver) external override callThroughEVC use(MODULE_VAULT) returns (uint256) {
        revert NOT_SUPPORTTED();
    }

}
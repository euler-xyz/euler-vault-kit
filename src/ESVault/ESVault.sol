// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVault} from "../EVault/EVault.sol";
import {IBorrowing} from "../EVault/IEVault.sol";
import {MarketCache} from "../EVault/shared/types/MarketCache.sol";
import "../EVault/shared/Constants.sol";
import {ProxyUtils} from "../EVault/shared/lib/ProxyUtils.sol";
import {IESynth} from "../ESynth/IESynth.sol";
import {IFlashLoan} from "../EVault/modules/Borrowing.sol";
import "../EVault/shared/types/Types.sol";

contract ESVault is EVault {
    using TypesLib for uint256;

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

    // ----------------- Initialize ----------------

    function initialize(address proxyCreator) public override virtual reentrantOK {
        super.initialize(proxyCreator);

        // disable not supported operations
        uint32 newDisabledOps = 
            OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_LOOP | OP_DELOOP | DisabledOps.unwrap(marketStorage.disabledOps);
        
        marketStorage.disabledOps = DisabledOps.wrap(newDisabledOps);
        emit GovSetDisabledOps(newDisabledOps);
    }

    // ----------------- Borrowing -----------------

    /// @inheritdoc IBorrowing
    function flashLoan(uint256 assets, bytes calldata data) external override nonReentrant {
        if (marketStorage.disabledOps.get(OP_FLASHLOAN)) {
            revert E_OperationDisabled();
        }

        (IERC20 asset,,) = ProxyUtils.metadata();
        address account = EVCAuthenticate();

        IESynth(address(asset)).mint(account, assets);
        IFlashLoan(account).onFlashLoan(data);

        // Expect tokens to be pushed back to vault so burn them from address(this). Will revert when tokens were not returned
        IESynth(address(asset)).burn(address(this), assets);
    }

    // ----------------- Governance -----------------
    function convertFees() external override nonReentrant {
        (MarketCache memory marketCache, address account) = initOperation(OP_CONVERT_FEES, ACCOUNTCHECK_NONE);

        if (marketCache.accumulatedFees.isZero()) return;

        (address protocolReceiver, uint256 protocolFee) = protocolConfig.feeConfig(address(this));
        address governorReceiver = marketStorage.feeReceiver;

        if (governorReceiver == address(0)) protocolFee = 1e18; // governor forfeits fees
        else if (protocolFee > MAX_PROTOCOL_FEE_SHARE) protocolFee = MAX_PROTOCOL_FEE_SHARE;

        Shares governorShares = marketCache.accumulatedFees.mulDiv(1e18 - protocolFee, 1e18);
        Shares protocolShares = marketCache.accumulatedFees - governorShares;

        marketStorage.accumulatedFees = marketCache.accumulatedFees = Shares.wrap(0);

        Assets governorAssets = governorShares.toAssetsDown(marketCache);
        Assets protocolAssets = protocolShares.toAssetsDown(marketCache);

        // Decrease totalShares because they are effectively withdrawn from the protocol
        marketStorage.totalShares =
            marketCache.totalShares = marketCache.totalShares - marketCache.accumulatedFees;

        // Mint synth to fee receivers
        if (governorReceiver != address(0)) {
            IESynth(address(marketCache.asset)).mint(governorReceiver, governorAssets.toUint());
        }

        IESynth(address(marketCache.asset)).mint(protocolReceiver, protocolAssets.toUint());

        emit ConvertFees(
            account,
            protocolReceiver,
            governorReceiver,
            protocolAssets.toUint(),
            governorAssets.toUint()
        );
    }

    // ----------------- Asset Transfers -----------------

    function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal virtual override {
        IESynth(address(marketCache.asset)).burn(from, amount.toUint());
        marketStorage.cash = marketCache.cash = marketCache.cash + amount;
    }

    function pushTokens(MarketCache memory marketCache, address to, Assets amount) internal virtual override {
        marketStorage.cash = marketCache.cash = marketCache.cash - amount;
        IESynth(address(marketCache.asset)).mint(to, amount.toUint());
    }

    // ----------------- Synth Specific -----------------
    
    function increaseCash(uint256 amount) external nonReentrant {
        // Update pending interest
        MarketCache memory marketCache = updateMarket();
        address account = EVCAuthenticate();
        // Should only be callable by the synth
        if(address(marketCache.asset) != account) revert E_Unauthorized();

        Assets assets = amount.toAssets();
        Shares shares = assets.toSharesDown(marketCache);
        if (shares.isZero()) revert E_ZeroShares();

        increaseBalance(marketCache, SYNTH_DEPOSIT_ADDRESS, account, shares, assets);
        marketStorage.cash = marketCache.cash = marketCache.cash + assets;
    }

    function decreaseCash(uint256 amount) external nonReentrant {
        // Update pending interest
        MarketCache memory marketCache = updateMarket();
        address account = EVCAuthenticate();
        // Should only be callable by the synth
        if(address(marketCache.asset) != account) revert E_Unauthorized();

        Assets assets = amount.toAssets() > marketCache.cash ? marketCache.cash : amount.toAssets();
        Shares shares = assets.toSharesUp(marketCache);

        decreaseBalance(marketCache, SYNTH_DEPOSIT_ADDRESS, account, address(0), shares, assets);
        marketStorage.cash = marketCache.cash = marketCache.cash - assets;
    }
}
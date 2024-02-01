// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./RiskManagerCoreLiquidation.sol";
import "../../oracles/IPriceOracle.sol";
import {IEVault} from "../../EVault/IEVault.sol";
import {IRiskManager} from "../../IRiskManager.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

import "../../EVault/shared/Constants.sol"; // TODO

interface IFactory {
    function isProxy(address) external view returns (bool);
}

contract RiskManagerCore is IRiskManager, RiskManagerCoreLiquidation {
    constructor(
        bytes32 gitCommit,
        address admin,
        address _factory,
        address _evc,
        address _defaultInterestRateModel,
        address _oracle
    ) RiskManagerCoreBase(gitCommit, _factory, _evc, _oracle) RiskManagerCoreGovernance(admin) {
        defaultInterestRateModel = _defaultInterestRateModel;
    }

    function activateMarket(address) external virtual override {
        if (!IFactory(factory).isProxy(msg.sender)) revert RM_Unauthorized();

        MarketConfig storage config = markets[msg.sender];
        if (config.activated) revert RM_MarketActivated();

        address asset = IERC4626(msg.sender).asset();

        if (asset == address(0) || asset == address(this) || asset == factory || asset == evc) {
            revert RM_InvalidUnderlying();
        }
        if (underlyingToMarket[asset] != address(0)) revert RM_UnderlyingActivated();

        uint8 decimals = IERC20(asset).decimals();
        if (decimals > 18) revert RM_TooManyDecimals();

        underlyingToMarket[asset] = msg.sender;

        config.activated = true;
        config.assetDecimals = decimals;
        config.borrowFactor = type(uint16).max;
        config.interestRateModel = defaultInterestRateModel;
        config.interestFee = type(uint16).max;

        PriceOracleCore(oracle).initPricingConfig(msg.sender, decimals, false);
    }

    // TODO handle vaults vs token collaterals - distinction now necessary by mock oracle
    function activateExternalMarket(address market) external {
        MarketConfig storage config = markets[market];
        if (config.activated) revert RM_MarketActivated();

        uint8 decimals = IERC20(market).decimals();
        if (decimals > 18) revert RM_TooManyDecimals();

        config.activated = true;
        config.assetDecimals = decimals;

        // Borrow factor and interest rate model are not initialized, making the market non-borrowable

        PriceOracleCore(oracle).initPricingConfig(market, uint8(decimals), true);
    }

    function marketName(address market) external view returns (string memory) {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();

        address asset = IERC4626(market).asset();
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) revertBytes(data);
        return string.concat("Euler Pool: ", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    function marketSymbol(address market) external view returns (string memory) {
        MarketConfig storage config = markets[market];
        if (!config.activated) revert RM_MarketNotActivated();

        address asset = IERC4626(market).asset();
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) revertBytes(data);
        return string.concat("e", data.length == 32 ? string(data) : abi.decode(data, (string)));
    }

    function collateralBalanceLocked(address collateral, address account, Liability memory liability)
        external
        view
        returns (uint256 lockedBalance)
    {
        if (liability.owed == 0) return 0;
        // TODO check liability is in RM?

        address[] memory collaterals = IEVC(evc).getCollaterals(account);
        (uint256 totalCollateralValueRA, uint256 liabilityValue) = computeLiquidity(account, collaterals, liability);

        if (liabilityValue == 0) return 0;

        uint256 collateralBalance = IERC20(collateral).balanceOf(account);
        if (liabilityValue >= totalCollateralValueRA) {
            return collateralBalance;
        }

        // check if collateral is enabled only for healthy account. In unhealthy state all withdrawals are blocked.
        {
            bool isCollateral;
            for (uint256 i; i < collaterals.length;) {
                if (collaterals[i] == collateral) {
                    isCollateral = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (!isCollateral) return 0;
        }

        uint256 collateralFactor;
        {
            MarketConfig memory liabilityConfig = resolveMarketConfig(liability.market);
            MarketConfig memory collateralConfig = resolveMarketConfig(collateral);

            collateralFactor = resolveCollateralFactor(collateral, liability.market, collateralConfig, liabilityConfig);
            if (collateralFactor == 0) return 0;
        }

        // calculate extra collateral value in terms of requested collateral shares (balance)
        uint256 extraCollateralValue = (totalCollateralValueRA - liabilityValue) * CONFIG_SCALE / collateralFactor;
        uint256 extraCollateralBalance;
        {
            // TODO use direct quote (below) when oracle supports both directions
            // uint extraCollateralBalance = PriceOracleCore(oracle).getQuote(extraCollateralValue, referenceAsset, collateral);
            uint256 quoteUnit = 1e18;
            uint256 collateralPrice = PriceOracleCore(oracle).getQuote(quoteUnit, collateral, referenceAsset);
            if (collateralPrice == 0) return 0; // worthless / unpriced collateral is not locked TODO what happens in liquidation??
            extraCollateralBalance = extraCollateralValue * quoteUnit / collateralPrice;
        }

        if (extraCollateralBalance >= collateralBalance) return 0; // other collaterals are sufficient to support the debt

        return collateralBalance - extraCollateralBalance;
    }

    function maxDeposit(address, address market) external view returns (uint256) {
        MarketConfig storage config = markets[market];

        // TODO optimize read
        bool activated = config.activated;
        uint256 supplyCap = config.supplyCap;
        uint256 decimals = config.assetDecimals;
        uint256 pauseBitmask = config.pauseBitmask;

        if (!activated) revert RM_MarketNotActivated();
        if (isExternalMarket(config)) revert RM_ExternalMarket();

        if (pauseBitmask & OP_DEPOSIT != 0) return 0;
        if (supplyCap == 0) return type(uint256).max;

        uint256 currentSupply = IERC4626(market).totalAssets();
        supplyCap = supplyCap * (10 ** decimals);

        return currentSupply < supplyCap ? supplyCap - currentSupply : 0;
    }

    // check if any operation in bitmask is paused
    function isPausedOperation(address market, uint32 operations) public view returns (bool) {
        MarketConfig storage config = markets[market];

        // TODO optimize read
        bool activated = config.activated;
        uint256 pauseBitmask = config.pauseBitmask;

        if (!activated) revert RM_MarketNotActivated();
        if (isExternalMarket(config)) revert RM_ExternalMarket();
        return operations & pauseBitmask > 0;
    }

    function computeAccountLiquidity(address account)
        external
        view
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        address controller = getSupportedController(account);
        address[] memory collaterals = IEVC(evc).getCollaterals(account);

        return computeLiquidity(
            account,
            collaterals,
            Liability(controller, IEVault(controller).asset(), IEVault(controller).debtOf(account))
        );
    }

    struct MarketLiquidity {
        address market;
        uint256 collateralValue;
        uint256 liabilityValue;
    }

    function computeAccountLiquidityPerMarket(address account) external view returns (MarketLiquidity[] memory) {
        Liability memory liability;
        liability.market = getSupportedController(account);
        liability.asset = IEVault(liability.market).asset();
        liability.owed = IEVault(liability.market).debtOf(account);

        address[] memory collaterals = IEVC(evc).getCollaterals(account);

        uint256 numMarkets = collaterals.length + 1;
        for (uint256 i; i < collaterals.length;) {
            if (collaterals[i] == liability.market) {
                numMarkets--;
                break;
            }
            unchecked {
                ++i;
            }
        }

        MarketLiquidity[] memory output = new MarketLiquidity[](numMarkets);
        address[] memory singleCollateral = new address[](1);

        // account also supplies collateral in liability market
        for (uint256 i; i < collaterals.length;) {
            output[i].market = collaterals[i];
            singleCollateral[0] = collaterals[i];

            (output[i].collateralValue, output[i].liabilityValue) =
                computeLiquidity(account, singleCollateral, liability);
            if (collaterals[i] != liability.market) output[i].liabilityValue = 0;

            unchecked {
                ++i;
            }
        }

        // liability market is not included in supplied collaterals
        if (numMarkets > collaterals.length) {
            singleCollateral[0] = liability.market;
            uint256 index = numMarkets - 1;

            output[index].market = liability.market;
            (output[index].collateralValue, output[index].liabilityValue) =
                computeLiquidity(account, singleCollateral, liability);
        }

        return output;
    }

    function checkAccountStatus(address account, address[] memory collaterals, Liability memory liability)
        external
        view
        override
    {
        if (liability.market == address(0) || liability.owed == 0) return;
        (uint256 collateralValue, uint256 liabilityValue) = computeLiquidity(account, collaterals, liability);

        if (collateralValue < liabilityValue) revert RM_AccountLiquidity();
    }

    function checkMarketStatus(
        address market,
        uint32 performedOperations,
        Snapshot memory oldSnapshot,
        Snapshot memory currentSnapshot
    ) external view override {
        MarketConfig storage config = markets[market];
        // TODO optimize reads
        bool activated = config.activated;
        uint256 pauseBitmask = config.pauseBitmask;
        uint256 supplyCap = config.supplyCap;
        uint256 borrowCap = config.borrowCap;
        uint256 assetDecimalsMultiplier = 10 ** config.assetDecimals;

        if (!activated || isExternalMarket(config)) revert RM_Unauthorized();
        if (pauseBitmask & performedOperations != 0) revert RM_OperationPaused();

        if (supplyCap == 0 && borrowCap == 0) return;

        uint256 totalAssets = currentSnapshot.poolSize + currentSnapshot.totalBorrows;
        if (
            supplyCap != 0 && totalAssets > (oldSnapshot.poolSize + oldSnapshot.totalBorrows)
                && totalAssets >= supplyCap * assetDecimalsMultiplier
        ) revert RM_SupplyCapExceeded();

        if (
            borrowCap != 0 && currentSnapshot.totalBorrows > oldSnapshot.totalBorrows
                && currentSnapshot.totalBorrows >= borrowCap * assetDecimalsMultiplier
        ) revert RM_BorrowCapExceeded();
    }

    // getters

    function getMarketByUnderlying(address asset) external view returns (address) {
        return underlyingToMarket[asset];
    }

    function computeInterestParams(address asset, uint32 utilisation)
        external
        override
        returns (uint256 interestRate, uint16 interestFee)
    {
        MarketConfig storage config = markets[msg.sender];
        if (!config.activated || isExternalMarket(config)) revert RM_Unauthorized();

        address irm = config.interestRateModel;
        uint16 fee = config.interestFee;

        try IIRM(irm).computeInterestRate(msg.sender, asset, utilisation) returns (uint256 ir) {
            interestRate = ir;
        } catch {}

        interestFee = fee == type(uint16).max ? DEFAULT_INTEREST_FEE : fee;
    }

    function getSupportedController(address account) internal view returns (address controller) {
        address[] memory controllers = IEVC(evc).getControllers(account);

        if (controllers.length > 1) revert RM_TransientState();
        if (controllers.length == 0) revert RM_NoLiability();

        controller = controllers[0];

        MarketConfig storage config = markets[controller];
        if (!config.activated || isExternalMarket(config)) revert RM_UnsupportedLiability();
        if (IEVault(controller).riskManager() != address(this)) revert RM_IncorrectRiskManager();
    }

    function computeLiquidity(address account, address[] memory collaterals, Liability memory liability)
        internal
        view
        virtual
        override
        returns (uint256 collateralValue, uint256 liabilityValue)
    {
        MarketConfig memory collateralConfig;
        MarketConfig memory liabilityConfig;

        // Count liability

        liabilityConfig = resolveMarketConfig(liability.market);
        //TODO // if (isExternalMarket(liabilityConfig)) revert RM_ExternalMarket();
        liabilityValue = PriceOracleCore(oracle).getQuote(liability.owed, liability.asset, referenceAsset);

        // Count collateral

        for (uint256 i; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            collateralConfig = resolveMarketConfig(collateral);
            uint256 collateralFactor =
                resolveCollateralFactor(collateral, liability.market, collateralConfig, liabilityConfig);
            if (collateralFactor == 0) continue;

            uint256 balance = IERC20(collateral).balanceOf(account); // TODO low level

            if (balance == 0) continue;

            uint256 currentCollateralValue = PriceOracleCore(oracle).getQuote(balance, collateral, referenceAsset);

            collateralValue += currentCollateralValue * collateralFactor / CONFIG_SCALE;
        }
    }
}

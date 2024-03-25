// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVault/EVault.sol";
import "../../InterestRateModels/IRMLinearKink.sol";
import "../../EVault/shared/lib/RPow.sol";

import "../../EVault/shared/Constants.sol";
import {IERC20} from "../../EVault/IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

import "hardhat/console.sol";

interface IExec {
    function getPriceFull(address underlying)
        external
        view
        returns (uint256 twap, uint256 twapPeriod, uint256 currPrice);
    function getPrice(address underlying) external view returns (uint256 twap, uint256 twapPeriod);
}

contract EulerLens {
    uint16 internal constant FEE_SCALE = 10_000;

    bytes32 public immutable moduleGitCommit;
    address public immutable evc;

    constructor(address evc_, bytes32 moduleGitCommit_) {
        evc = evc_;
        moduleGitCommit = moduleGitCommit_;
    }

    // Query
    struct Query {
        address account;
        address[] markets;
    }

    // Response

    struct Override {
        address underlying;
        uint16 collateralFactor;
    }

    struct ResponseMarket {
        // Universal
        address underlying;
        string name;
        string symbol;
        uint8 decimals;
        address eVaultAddr;
        address dTokenAddr;
        // Storage.AssetConfig config;
        uint256 poolSize;
        uint256 totalAssets;
        uint256 totalBorrows;
        uint256 accumulatedFees;
        uint16 reserveFee;
        uint256 borrowAPY;
        uint256 supplyAPY;
        // Pricing
        uint256 twap;
        uint256 twapPeriod;
        uint256 currPrice;
        uint16 pricingType;
        uint32 pricingParameters;
        address pricingForwarded;
        // Account specific
        uint256 underlyingBalance;
        uint256 eulerAllowance;
        uint256 eVaultBalance;
        uint256 eVaultBalanceUnderlying;
        uint256 dTokenBalance;
        uint256 collateralValue;
        uint256 liabilityValue;
        // Overrides
        Override[] overrideLiabilities;
        Override[] overrideCollaterals;
    }

    struct Response {
        uint256 timestamp;
        uint256 blockNumber;
        ResponseMarket[] markets;
        address[] enteredMarkets;
    }

    // Implementation

    function doQueryBatch(Query[] memory qs) external view returns (Response[] memory r) {
        r = new Response[](qs.length);

        for (uint256 i = 0; i < qs.length; ++i) {
            r[i] = doQuery(qs[i]);
        }
    }

    function doQuery(Query memory q) public view returns (Response memory r) {
        r.timestamp = block.timestamp;
        r.blockNumber = block.number;

        address[] memory collaterals;
        uint256[] memory collateralValues;
        uint256 liabilityValue;

        if (q.account != address(0)) {
            address controller = IEVC(evc).getControllers(q.account)[0];
            (collaterals, collateralValues, liabilityValue) = EVault(controller).accountLiquidityFull(q.account, false);
        }

        r.markets = new ResponseMarket[](collaterals.length + q.markets.length);

        for (uint256 i = 0; i < collaterals.length; ++i) {
            ResponseMarket memory m = r.markets[i];

            m.eVaultAddr = collaterals[i];
            m.underlying = EVault(m.eVaultAddr).asset();
            // m.liquidityStatus = liqs[i].status;

            populateResponseMarket(q, m);
        }

        for (uint256 j = collaterals.length; j < collaterals.length + q.markets.length; ++j) {
            uint256 i = j - collaterals.length;
            ResponseMarket memory m = r.markets[j];

            m.eVaultAddr = q.markets[i];
            m.underlying = EVault(m.eVaultAddr).asset();

            populateResponseMarket(q, m);
        }
        if (q.account != address(0)) {
            r.enteredMarkets = IEVC(evc).getCollaterals(q.account);
        }
    }

    function populateResponseMarket(Query memory q, ResponseMarket memory m)
        private
        view
    {
        m.name = getStringOrBytes32(m.underlying, IERC20.name.selector);
        m.symbol = getStringOrBytes32(m.underlying, IERC20.symbol.selector);

        m.decimals = IERC20(m.underlying).decimals();

        if (m.eVaultAddr == address(0)) return; // not activated
        // m.dTokenAddr = marketsProxy.marketToDToken(m.eVaultAddr);
        // {
        //     Storage.AssetConfig memory c = marketsProxy.underlyingToAssetConfig(m.underlying);
        //     m.config = c;
        // }

        m.poolSize = IERC20(m.underlying).balanceOf(m.eVaultAddr);
        m.totalAssets = EVault(m.eVaultAddr).totalAssets();
        m.totalBorrows = EVault(m.eVaultAddr).totalBorrows();
        m.accumulatedFees = EVault(m.eVaultAddr).accumulatedFeesAssets();
        m.reserveFee = EVault(m.eVaultAddr).interestFee();

        {
            uint256 borrowSPY = EVault(m.eVaultAddr).interestRate();
            (m.borrowAPY, m.supplyAPY) = computeAPYs(borrowSPY, m.totalBorrows, m.totalAssets, m.reserveFee);
        }

        // (m.twap, m.twapPeriod, m.currPrice) = execProxy.getPriceFull(m.underlying);
        // (m.pricingType, m.pricingParameters, m.pricingForwarded) = marketsProxy.getPricingConfig(m.underlying);

        if (q.account == address(0)) return;

        m.underlyingBalance = IERC20(m.underlying).balanceOf(q.account);
        m.eVaultBalance = IERC20(m.eVaultAddr).balanceOf(q.account);
        m.eVaultBalanceUnderlying = EVault(m.eVaultAddr).maxWithdraw(q.account);
        m.dTokenBalance = IERC20(m.dTokenAddr).balanceOf(q.account);
        m.eulerAllowance = IERC20(m.underlying).allowance(q.account, m.eVaultAddr);

        // {
        //     address[] memory overrideCollaterals = riskManager.getOverrideCollaterals(m.eVaultAddr);
        //     m.overrideCollaterals = new Override[](overrideCollaterals.length);
        //     for (uint256 i = 0; i < overrideCollaterals.length; i++) {
        //         m.overrideCollaterals[i] = Override({
        //             underlying: overrideCollaterals[i],
        //             collateralFactor: riskManager.getOverride(m.eVaultAddr, overrideCollaterals[i]).collateralFactor
        //         });
        //     }

        //     address[] memory overrideLiabilities = riskManager.getOverrideLiabilities(m.eVaultAddr);
        //     m.overrideLiabilities = new Override[](overrideLiabilities.length);
        //     for (uint256 i = 0; i < overrideLiabilities.length; i++) {
        //         m.overrideLiabilities[i] = Override({
        //             underlying: overrideLiabilities[i],
        //             collateralFactor: riskManager.getOverride(overrideLiabilities[i], m.eVaultAddr).collateralFactor
        //         });
        //     }
        // }
    }

    function computeAPYs(uint256 borrowSPY, uint256 totalBorrows, uint256 totalBalancesUnderlying, uint16 reserveFee)
        public
        pure
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        (borrowAPY,) = RPow.rpow(borrowSPY + 1e27, SECONDS_PER_YEAR, 10 ** 27);
        borrowAPY =  borrowAPY - 1e27;

        uint256 supplySPY = totalBalancesUnderlying == 0 ? 0 : borrowSPY * totalBorrows / totalBalancesUnderlying;
        supplySPY = supplySPY * (FEE_SCALE - reserveFee) / FEE_SCALE;
        (supplyAPY,) = RPow.rpow(supplySPY + 1e27, SECONDS_PER_YEAR, 10 ** 27);
        supplyAPY = supplyAPY - 1e27;
    }

    // Interest rate model queries

    struct QueryIRM {
        address eulerContract;
        address market;
    }

    struct ResponseIRM {
        uint256 kink;
        uint256 baseAPY;
        uint256 kinkAPY;
        uint256 maxAPY;
        uint256 baseSupplyAPY;
        uint256 kinkSupplyAPY;
        uint256 maxSupplyAPY;
    }

    function doQueryIRM(QueryIRM memory q) external view returns (ResponseIRM memory r) {
        // RiskManagerCore riskManager = RiskManagerCore(EVault(q.market).riskManager());

        // BaseIRMLinearKink irm = BaseIRMLinearKink(riskManager.interestRateModel(q.market));

        // uint256 kink = r.kink = irm.kink();
        // // uint32 interestFee = marketsProxy.interestFee(q.market);
        // uint16 interestFee = 0; //marketsProxy.interestFee(q.market);

        // uint256 baseSPY = irm.baseRate();
        // uint256 kinkSPY = baseSPY + (kink * irm.slope1());
        // uint256 maxSPY = kinkSPY + ((type(uint32).max - kink) * irm.slope2());

        // (r.baseAPY, r.baseSupplyAPY) = computeAPYs(baseSPY, 0, type(uint32).max, interestFee);
        // (r.kinkAPY, r.kinkSupplyAPY) = computeAPYs(kinkSPY, kink, type(uint32).max, interestFee);
        // (r.maxAPY, r.maxSupplyAPY) = computeAPYs(maxSPY, type(uint32).max, type(uint32).max, interestFee);
    }

    // AccountLiquidity queries

    // struct ResponseAccountLiquidity {
    //     IRiskManager.AssetLiquidity[] markets;
    // }

    // function doQueryAccountLiquidity(address eulerContract, address[] memory addrs) external view returns (ResponseAccountLiquidity[] memory r) {
    //     Euler eulerProxy = Euler(eulerContract);
    //     IExec execProxy = IExec(eulerProxy.moduleIdToProxy(MODULEID__EXEC));

    //     r = new ResponseAccountLiquidity[](addrs.length);

    //     for (uint i = 0; i < addrs.length; ++i) {
    //         r[i].markets = execProxy.liquidityPerAsset(addrs[i]);
    //     }
    // }

    // For tokens like MKR which return bytes32 on name() or symbol()

    function getStringOrBytes32(address contractAddress, bytes4 selector) private view returns (string memory) {
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(selector));
        if (!success) return "";

        return result.length == 32 ? string(abi.encodePacked(result)) : abi.decode(result, (string));
    }
}

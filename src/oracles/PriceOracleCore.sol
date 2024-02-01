// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IPriceOracle.sol";
import "../vendor/TickMath.sol";
import "../vendor/FullMath.sol";

import {IERC4626, IERC20} from "contracts/EVault/IEVault.sol";

import "hardhat/console.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function liquidity() external view returns (uint128);
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives);
    function observations(uint256 index)
        external
        view
        returns (uint32 blockTimestamp, int56 tickCumulative, uint160 liquidityCumulative, bool initialized);
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

interface IChainlinkAggregatorV2V3 {
    function latestAnswer() external view returns (int256);
}

interface IFactory {
    function isProxy(address) external view returns (bool);
}

contract PriceOracleCore is IPriceOracle {
    string public constant name = "Euler Core Price Oracle";
    // Pricing

    uint24 internal constant DEFAULT_TWAP_WINDOW_SECONDS = 30 * 60;
    uint16 internal constant MIN_UNISWAP3_OBSERVATION_CARDINALITY = 144;

    // Pricing types
    uint16 internal constant PRICINGTYPE__UNINITIALIZED = 0;
    uint16 internal constant PRICINGTYPE__PEGGED = 1;
    uint16 internal constant PRICINGTYPE__UNISWAP3_TWAP = 2;
    uint16 internal constant PRICINGTYPE__CHAINLINK = 3;
    uint16 internal constant PRICINGTYPE__NESTED = 4;
    // Correct pricing types are always less than this value
    uint16 internal constant PRICINGTYPE__OUT_OF_BOUNDS = 5;

    error POC_NoUniswapPoolAvailable();
    error POC_BadUniswapPoolAddress();
    error POC_UniswapPoolNotInited();
    error POC_Uniswap(string msg);
    error POC_BadPricingType();
    error POC_ChainlinkPriceFeedNotInitialized();
    error POC_BadChainlinkAddress();
    error POC_UnknownPricingType();
    error POC_AssetInitialized();
    error POC_AssetNotInitialized();
    error POC_UnableToGetPrice();
    error POC_EmptyError();
    error POC_Unauthorized();
    error POC_NestedAssetNotInitialized();

    event SetGovernorAdmin(address indexed newGovernorAdmin);
    event GovSetChainlinkPriceFeed(address indexed asset, address chainlinkAggregator);
    event GovSetPricingConfig(address indexed asset, uint16 newPricingType, uint32 newPricingParameter);

    struct OracleSettings {
        address referenceAsset;
        address uniswapFactory;
        bytes32 uniswapPoolInitCodeHash;
    }

    // Construction
    address immutable vaultFactory;
    address public immutable referenceAsset; // Token must have 18 decimals
    address immutable uniswapFactory;
    bytes32 immutable uniswapPoolInitCodeHash;

    struct AssetConfig {
        uint16 pricingType;
        uint32 pricingParameters;
        uint8 decimals;
        uint24 twapWindow;
    }

    address governorAdmin;
    mapping(address asset => AssetConfig) assets;
    mapping(address asset => address chainlinkAggregator) internal chainlinkPriceFeedLookup;
    mapping(address asset => address nestedAsset) nestedAssets;

    constructor(address _governorAdmin, address _vaultFactory, OracleSettings memory settings) {
        governorAdmin = _governorAdmin;
        vaultFactory = _vaultFactory;

        referenceAsset = settings.referenceAsset;
        uniswapFactory = settings.uniswapFactory;
        uniswapPoolInitCodeHash = settings.uniswapPoolInitCodeHash;
    }

    function getQuote(uint256 amount, address base, address quote) external view returns (uint256 out) {
        if (quote != referenceAsset) revert PO_QuoteUnsupported();

        AssetConfig memory config = resolveAssetConfig(base);
        if (config.pricingType == PRICINGTYPE__UNINITIALIZED) revert PO_BaseUnsupported();
        (uint256 twap,) = getPriceInternal(base, config);
        return twap * amount * (10 ** (18 - config.decimals)) / 1e18;
    }

    function getQuotes(uint256 amount, address base, address quote)
        external
        view
        returns (uint256 bidOut, uint256 askOut)
    {}

    function getTick(uint256 amount, address base, address quote) external view returns (uint256 tick) {}

    function getTicks(uint256 amount, address base, address quote)
        external
        view
        returns (uint256 bidTick, uint256 askTick)
    {}

    function getPrice(address asset) public view returns (uint256 twap, uint256 twapPeriod) {
        AssetConfig memory config = resolveAssetConfig(asset);
        if (config.pricingType == PRICINGTYPE__UNINITIALIZED) revert PO_BaseUnsupported();
        (twap, twapPeriod) = getPriceInternal(asset, config);
    }

    // This function is only meant to be called from a view so it doesn't need to be optimised.
    // The Euler protocol itself doesn't ever use currPrice as returned by this function.

    function getPriceFull(address asset) external view returns (uint256 twap, uint256 twapPeriod, uint256 currPrice) {
        AssetConfig memory config = resolveAssetConfig(asset);
        if (config.pricingType == PRICINGTYPE__UNINITIALIZED) revert PO_BaseUnsupported();

        (twap, twapPeriod) = getPriceInternal(asset, config);

        uint16 pricingType = config.pricingType;

        uint256 assetDecimalsScaler = 10 ** (18 - config.decimals);

        if (pricingType == PRICINGTYPE__PEGGED) {
            currPrice = 1e18;
        } else if (pricingType == PRICINGTYPE__UNISWAP3_TWAP) {
            address pool = computeUniswapPoolAddress(asset, uint24(config.pricingParameters));
            (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            currPrice = decodeSqrtPriceX96(asset, assetDecimalsScaler, sqrtPriceX96);
        } else if (pricingType == PRICINGTYPE__CHAINLINK) {
            currPrice = twap;
        } else {
            revert POC_UnknownPricingType();
        }
    }

    function initPricingConfig(address asset, uint8 decimals, bool isExternalVault) external {
        // TODO access control
        initPricingConfigInternal(asset, decimals, isExternalVault);
    }

    function initPricingConfigInternal(address asset, uint8 decimals, bool isExternalVault) internal {
        AssetConfig storage config = assets[asset];
        if (config.pricingType != PRICINGTYPE__UNINITIALIZED) return;

        config.twapWindow = type(uint24).max;
        config.decimals = decimals;

        if (asset == referenceAsset) {
            // 1:1 peg

            config.pricingType = PRICINGTYPE__PEGGED;
            config.pricingParameters = uint32(0);
        } else if (isExternalVault || IFactory(vaultFactory).isProxy(asset)) {
            address nestedAsset = IERC4626(asset).asset();
            if (assets[nestedAsset].pricingType == PRICINGTYPE__UNINITIALIZED) {
                initPricingConfigInternal(nestedAsset, IERC20(nestedAsset).decimals(), false);
            }

            nestedAssets[asset] = nestedAsset;

            config.pricingType = PRICINGTYPE__NESTED;
        } else {
            // Uniswap3 TWAP

            // The uniswap pool (fee-level) with the highest in-range liquidity is used by default.
            // This is a heuristic and can easily be manipulated by the activator, so users should
            // verify the selection is suitable before using the pool. Otherwise, governance will
            // need to change the pricing config for the market.

            address pool = address(0);
            uint24 fee = 0;

            {
                uint24[4] memory fees = [uint24(3000), 10000, 500, 100];
                uint128 bestLiquidity = 0;

                for (uint256 i = 0; i < fees.length; ++i) {
                    address candidatePool = IUniswapV3Factory(uniswapFactory).getPool(asset, referenceAsset, fees[i]);
                    if (candidatePool == address(0)) continue;

                    uint128 liquidity = IUniswapV3Pool(candidatePool).liquidity();

                    if (pool == address(0) || liquidity > bestLiquidity) {
                        pool = candidatePool;
                        fee = fees[i];
                        bestLiquidity = liquidity;
                    }
                }
            }

            if (pool == address(0)) revert POC_NoUniswapPoolAvailable();
            if (computeUniswapPoolAddress(asset, fee) != pool) revert POC_BadUniswapPoolAddress();

            config.pricingType = PRICINGTYPE__UNISWAP3_TWAP;
            config.pricingParameters = uint32(fee);

            try IUniswapV3Pool(pool).increaseObservationCardinalityNext(MIN_UNISWAP3_OBSERVATION_CARDINALITY) {
                // Success
            } catch Error(string memory err) {
                if (keccak256(bytes(err)) == keccak256("LOK")) revert POC_UniswapPoolNotInited();
                revert POC_Uniswap(string(err));
            } catch (bytes memory returnData) {
                revertBytes(returnData);
            }
        }
    }

    function getPriceInternal(address asset, AssetConfig memory config)
        public
        view
        returns (uint256 twap, uint256 twapPeriod)
    {
        uint16 pricingType = config.pricingType;
        uint256 assetDecimalsScaler = 10 ** (18 - config.decimals);
        if (pricingType == PRICINGTYPE__PEGGED) {
            twap = 1e18;
            twapPeriod = config.twapWindow;
        } else if (pricingType == PRICINGTYPE__UNISWAP3_TWAP) {
            address pool = computeUniswapPoolAddress(asset, uint24(config.pricingParameters));
            (twap, twapPeriod) = callUniswapObserve(asset, assetDecimalsScaler, pool, config.twapWindow);
        } else if (pricingType == PRICINGTYPE__CHAINLINK) {
            twap = callChainlinkLatestAnswer(chainlinkPriceFeedLookup[asset]);
            twapPeriod = 0;

            // if price invalid and uniswap fallback pool configured get the price from uniswap
            if (twap == 0 && uint24(config.pricingParameters) != 0) {
                address pool = computeUniswapPoolAddress(asset, uint24(config.pricingParameters));
                (twap, twapPeriod) = callUniswapObserve(asset, assetDecimalsScaler, pool, config.twapWindow);
            }

            if (twap == 0) revert POC_UnableToGetPrice();
        } else if (pricingType == PRICINGTYPE__NESTED) {
            address nestedAsset = nestedAssets[asset];
            (twap, twapPeriod) = getPriceInternal(nestedAsset, resolveAssetConfig(nestedAsset));
            twap = twap * IERC4626(asset).convertToAssets(10 ** config.decimals) / (10 ** config.decimals);
        } else {
            revert POC_UnknownPricingType();
        }
    }

    function computeUniswapPoolAddress(address asset, uint24 fee) internal view returns (address) {
        address tokenA = asset;
        address tokenB = referenceAsset;
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", uniswapFactory, keccak256(abi.encode(tokenA, tokenB, fee)), uniswapPoolInitCodeHash
                        )
                    )
                )
            )
        );
    }

    function decodeSqrtPriceX96(address asset, uint256 assetDecimalsScaler, uint256 sqrtPriceX96)
        private
        view
        returns (uint256 price)
    {
        if (uint160(asset) < uint160(referenceAsset)) {
            price = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, uint256(2 ** (96 * 2)) / 1e18) / assetDecimalsScaler;
        } else {
            price = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, uint256(2 ** (96 * 2)) / (1e18 * assetDecimalsScaler));
            if (price == 0) return 1e36;
            price = 1e36 / price;
        }

        if (price > 1e36) price = 1e36;
        else if (price == 0) price = 1;
    }

    function callUniswapObserve(address asset, uint256 assetDecimalsScaler, address pool, uint256 ago)
        private
        view
        returns (uint256, uint256)
    {
        uint32[] memory secondsAgos = new uint32[](2);

        secondsAgos[0] = uint32(ago);
        secondsAgos[1] = 0;

        (bool success, bytes memory data) = pool.staticcall(abi.encodeCall(IUniswapV3Pool.observe, secondsAgos));

        if (!success) {
            if (keccak256(data) != keccak256(abi.encodeWithSignature("Error(string)", "OLD"))) revertBytes(data);
            // The oldest available observation in the ring buffer is the index following the current (accounting for wrapping),
            // since this is the one that will be overwritten next.

            (,, uint16 index, uint16 cardinality,,,) = IUniswapV3Pool(pool).slot0();

            (uint32 oldestAvailableAge,,, bool initialized) =
                IUniswapV3Pool(pool).observations((index + 1) % cardinality);

            // If the following observation in a ring buffer of our current cardinality is uninitialized, then all the
            // observations at higher indices are also uninitialized, so we wrap back to index 0, which we now know
            // to be the oldest available observation.

            if (!initialized) (oldestAvailableAge,,,) = IUniswapV3Pool(pool).observations(0);

            // Call observe() again to get the oldest available

            ago = block.timestamp - oldestAvailableAge;
            secondsAgos[0] = uint32(ago);

            (success, data) = pool.staticcall(abi.encodeCall(IUniswapV3Pool.observe, secondsAgos));
            if (!success) revertBytes(data);
        }

        // If uniswap pool doesn't exist, then data will be empty and this decode will throw:

        int56[] memory tickCumulatives = abi.decode(data, (int56[])); // don't bother decoding the liquidityCumulatives array

        int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int256(ago)));

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        return (decodeSqrtPriceX96(asset, assetDecimalsScaler, sqrtPriceX96), ago);
    }

    function callChainlinkLatestAnswer(address chainlinkAggregator) private view returns (uint256 price) {
        // IMPORTANT as per H-03 item from August 2022 WatchPug audit:
        // if Chainlink starts using shorter heartbeats and/or before deploying to the sidechain/L2,
        // the latestAnswer call should be replaced by latestRoundData and updatedTime should be checked
        // to detect staleness of the oracle
        (bool success, bytes memory data) =
            chainlinkAggregator.staticcall(abi.encodeWithSelector(IChainlinkAggregatorV2V3.latestAnswer.selector));

        if (!success) {
            return 0;
        }

        int256 answer = abi.decode(data, (int256));
        if (answer <= 0) {
            return 0;
        }

        price = uint256(answer);
        if (price > 1e36) price = 1e36;
    }

    function resolveAssetConfig(address asset) internal view returns (AssetConfig memory) {
        AssetConfig memory config = assets[asset];
        if (config.twapWindow == type(uint24).max) config.twapWindow = DEFAULT_TWAP_WINDOW_SECONDS;

        return config;
    }

    // GOVERNANCE

    modifier governorOnly() {
        if (msg.sender != governorAdmin) revert POC_Unauthorized();
        _;
    }

    function setPricingConfig(address asset, uint16 newPricingType, uint32 newPricingParameter, uint24 newTwapWindow)
        external
        governorOnly
    {
        AssetConfig storage config = assets[asset];

        if (config.pricingType == PRICINGTYPE__UNINITIALIZED) revert POC_AssetNotInitialized();

        if (newPricingType == 0 || newPricingType >= PRICINGTYPE__OUT_OF_BOUNDS) revert POC_BadPricingType();

        config.pricingType = newPricingType;
        config.pricingParameters = newPricingParameter;
        config.twapWindow = newTwapWindow;

        if (newPricingType == PRICINGTYPE__CHAINLINK) {
            if (chainlinkPriceFeedLookup[asset] == address(0)) revert POC_ChainlinkPriceFeedNotInitialized();
        }

        emit GovSetPricingConfig(asset, newPricingType, newPricingParameter);
    }

    function setChainlinkPriceFeed(address asset, address chainlinkAggregator) external governorOnly {
        if (chainlinkAggregator == address(0)) revert POC_BadChainlinkAddress();

        chainlinkPriceFeedLookup[asset] = chainlinkAggregator;

        emit GovSetChainlinkPriceFeed(asset, chainlinkAggregator);
    }

    // Getters

    /// @notice Retrieves the pricing config for a market
    /// @param asset Token address
    /// @return pricingType (1=pegged, 2=uniswap3, 3=chainlink)
    /// @return pricingParameters If uniswap3 pricingType then this represents the uniswap pool fee used, if chainlink pricing type this represents the fallback uniswap pool fee or 0 if none
    function getPricingConfig(address asset) external view returns (uint16 pricingType, uint32 pricingParameters) {
        AssetConfig storage config = assets[asset];

        pricingType = config.pricingType;
        pricingParameters = config.pricingParameters;
    }

    /// @notice Retrieves the Chainlink price feed config for an asset
    /// @param asset Token address
    /// @return chainlinkAggregator Chainlink aggregator proxy address
    function getChainlinkPriceFeedConfig(address asset) external view returns (address chainlinkAggregator) {
        chainlinkAggregator = chainlinkPriceFeedLookup[asset];
    }

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert POC_EmptyError();
    }
}

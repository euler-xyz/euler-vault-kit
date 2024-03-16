// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";
import {Errors} from "src/lib/Errors.sol";
import {Governable} from "src/lib/Governable.sol";

/// @title EulerRouter
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Default Oracle resolver for Euler lending products.
contract EulerRouter is Governable, IPriceOracle {
    /// @notice The PriceOracle to call if this router is not configured for base/quote.
    /// @dev If `address(0)` then there is no fallback.
    address public fallbackOracle;
    /// @notice PriceOracle configured for base/quote.
    mapping(address base => mapping(address quote => address oracle)) public oracles;
    /// @notice ERC4626 vaults to resolve using internal pricing.
    /// @dev During resolution the vault is substituted with its asset.
    /// The `inAmount` is augmented by the vault's `convert*` function.
    mapping(address vault => address asset) public resolvedVaults;

    /// @notice Configure a PriceOracle to resolve base/quote.
    /// @param base The address of the base token.
    /// @param quote The address of the quote token.
    /// @param oracle The address of the PriceOracle that resolves base/quote.
    /// @dev If `oracle` is `address(0)` then the base/quote configuration was removed.
    event ConfigSet(address indexed base, address indexed quote, address indexed oracle);
    /// @notice Set a PriceOracle as a fallback resolver.
    /// @param fallbackOracle The address of the PriceOracle that is called when base/quote is not configured.
    /// @dev If `fallbackOracle` is `address(0)` then there is no fallback resolver.
    event FallbackOracleSet(address indexed fallbackOracle);
    /// @notice Mark an ERC4626 vault to be resolved to its `asset` via its `convert*` methods.
    /// @param vault The address of the ERC4626 vault.
    /// @param asset The address of the vault's asset.
    /// @dev If `asset` is `address(0)` then the configuration was removed.
    event ResolvedVaultSet(address indexed vault, address indexed asset);

    /// @notice Deploy EulerRouter.
    /// @param _governor The address of the governor.
    constructor(address _governor) Governable(_governor) {}

    /// @notice Configure a PriceOracle to resolve base/quote.
    /// @param base The address of the base token.
    /// @param quote The address of the quote token.
    /// @param oracle The address of the PriceOracle that resolves base/quote.
    /// @dev Callable only by the governor.
    function govSetConfig(address base, address quote, address oracle) external onlyGovernor {
        oracles[base][quote] = oracle;
        emit ConfigSet(base, quote, oracle);
    }

    /// @notice Configure an ERC4626 vault to use internal pricing via `convert*` methods.
    /// @param vault The address of the ERC4626 vault.
    /// @param set True to configure the vault, false to clear the record.
    /// @dev Callable only by the governor. Vault must be ERC4626.
    /// Only configure internal pricing after verifying that the implementation of
    /// `convertToAssets` and `convertToShares` cannot be manipulated.
    function govSetResolvedVault(address vault, bool set) external onlyGovernor {
        address asset = set ? IERC4626(vault).asset() : address(0);
        resolvedVaults[vault] = asset;
        emit ResolvedVaultSet(vault, asset);
    }

    /// @notice Set a PriceOracle as a fallback resolver.
    /// @param _fallbackOracle The address of the PriceOracle that is called when base/quote is not configured.
    /// @dev `address(0)` removes the fallback.
    function govSetFallbackOracle(address _fallbackOracle) external onlyGovernor {
        fallbackOracle = _fallbackOracle;
        emit FallbackOracleSet(_fallbackOracle);
    }

    /// @inheritdoc IPriceOracle
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        address oracle;
        (inAmount, base, quote, oracle) = _resolveOracle(inAmount, base, quote);
        if (base == quote) return inAmount;
        return IPriceOracle(oracle).getQuote(inAmount, base, quote);
    }

    /// @inheritdoc IPriceOracle
    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        address oracle;
        (inAmount, base, quote, oracle) = _resolveOracle(inAmount, base, quote);
        if (base == quote) return (inAmount, inAmount);
        return IPriceOracle(oracle).getQuotes(inAmount, base, quote);
    }

    /// @notice Resolve the PriceOracle to call for a given base/quote pair.
    /// @param inAmount The amount of `base` to convert.
    /// @param base The token that is being priced.
    /// @param quote The token that is the unit of account.
    /// @dev Implements the following recursive resolution logic:
    /// 1. Check the base case: `base == quote` and terminate if true.
    /// 2. If a PriceOracle is configured for base/quote in the `oracles` mapping,
    ///    return it without transforming the other variables.
    /// 3. If `base` is configured as an ERC4626 vault with internal pricing,
    ///    transform inAmount by calling `convertToAssets` and recurse by substituting `asset` for `base`.
    /// 4. If `quote` is configured as an ERC4626 vault with internal pricing,
    ///    transform inAmount by calling `convertToAssets` and recurse by substituting `asset` for `quote`.
    /// 5. If there is a fallback oracle, return it without transforming the other variables, else revert.
    /// @return The resolved inAmount.
    /// @return The resolved base.
    /// @return The resolved quote.
    /// @return The resolved PriceOracle to call.
    function _resolveOracle(uint256 inAmount, address base, address quote)
        internal
        view
        returns (uint256, /* inAmount */ address, /* base */ address, /* quote */ address /* oracle */ )
    {
        // Check the base case
        if (base == quote) return (inAmount, base, quote, address(0));
        // 1. Check if base/quote is configured.
        address oracle = oracles[base][quote];
        if (oracle != address(0)) return (inAmount, base, quote, oracle);
        // 2. Recursively resolve `base`.
        address baseAsset = resolvedVaults[base];
        if (baseAsset != address(0)) {
            inAmount = IERC4626(base).convertToAssets(inAmount);
            return _resolveOracle(inAmount, baseAsset, quote);
        }
        // 3. Recursively resolve `quote`.
        address quoteAsset = resolvedVaults[quote];
        if (quoteAsset != address(0)) {
            inAmount = IERC4626(quote).convertToShares(inAmount);
            return _resolveOracle(inAmount, base, quoteAsset);
        }
        // 4. Return the fallback or revert if not configured.
        oracle = fallbackOracle;
        if (oracle == address(0)) revert Errors.PriceOracle_NotSupported(base, quote);
        return (inAmount, base, quote, oracle);
    }
}

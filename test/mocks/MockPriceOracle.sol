// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC4626, IERC20} from "../../src/EVault/IEVault.sol";

contract MockPriceOracle {
    mapping(address base => mapping(address quote => uint256)) public prices;
    mapping(address vault => address asset) public resolvedVaults;

    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        uint256 price;        
        (inAmount, base, quote, price) = _resolveOracle(inAmount, base, quote);

        (bool success, bytes memory data) = address(base).staticcall(abi.encodeWithSelector(IERC20(base).decimals.selector));
        uint8 decimals = success && data.length >= 32 ? abi.decode(data, (uint8)) : 18;

        if (base == quote) {
            return inAmount;
        } else {
            return price * inAmount / 10 ** decimals;
        }
    }

    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        uint256 price;
        (inAmount, base, quote, price) = _resolveOracle(inAmount, base, quote);

        (bool success, bytes memory data) = address(base).staticcall(abi.encodeWithSelector(IERC20(base).decimals.selector));
        uint8 decimals = success && data.length >= 32 ? abi.decode(data, (uint8)) : 18;

        uint256 outAmount;
        if (base == quote) {
            outAmount = inAmount;
        } else {
            outAmount = price * inAmount / 10 ** decimals;
        }

        return (outAmount, outAmount);
    }

    function _resolveOracle(uint256 inAmount, address base, address quote)
        internal
        view
        returns (uint256, /* inAmount */ address, /* base */ address, /* quote */ uint256 /* price */ )
    {
        // Check the base case
        if (base == quote) return (inAmount, base, quote, inAmount);

        // 1. Check if base/quote is configured.
        uint256 price = prices[base][quote];
        if (price != 0) return (inAmount, base, quote, price);

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

        return (inAmount, base, quote, price);
    }

    ///// Mock functions

    function setPrice(address base, address quote, uint256 price) external {
        prices[base][quote] = price;
    }

    function setResolvedVault(address vault, bool set) external {
        address asset = set ? IERC4626(vault).asset() : address(0);
        resolvedVaults[vault] = asset;
    }

    function testExcludeFromCoverage() public pure {
        return;
    }
}

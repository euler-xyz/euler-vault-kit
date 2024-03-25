// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./swapHandlers/ISwapHandler.sol";
import {IERC20, IEVault} from "../../EVault/IEVault.sol";

import "hardhat/console.sol";

/// @notice Common logic for executing and processing trades through external swap handler contracts
contract SwapHub {
    struct SwapCache {
        address accountIn;
        address accountOut;
        address eTokenIn;
        address eTokenOut;
        uint preBalanceIn;
        uint preBalanceOut;
    }

    // TODO: swap is not needed for anything other than verifying amounts out, there could be a helper just doing that (transient snapshot?)
    function swap(address accountIn, address accountOut, address eTokenIn, address eTokenOut, address swapHandler, ISwapHandler.SwapParams memory params) external {
        SwapCache memory cache = initSwap(accountIn, accountOut, eTokenIn, eTokenOut, params);

        uint amountOut = swapInternal(cache, swapHandler, params);

        IERC20(params.underlyingOut).approve(cache.eTokenOut, type(uint256).max);
        IEVault(cache.eTokenOut).deposit(amountOut, cache.accountOut);
    }


    function swapAndRepay(address accountIn, address accountOut, address eTokenIn, address eTokenOut, address swapHandler, ISwapHandler.SwapParams memory params, uint targetDebt) external {
        SwapCache memory cache = initSwap(accountIn, accountOut, eTokenIn, eTokenOut, params);

        // Adjust params for repay
        require(params.mode == 1, "e/swap-hub/repay-mode");

        uint owed = IEVault(eTokenOut).debtOf(accountOut);
        require (owed > targetDebt, "e/swap-hub/target-debt");
        params.amountOut = owed - targetDebt;

        uint amountOut = swapInternal(cache, swapHandler, params);

        IERC20(params.underlyingOut).approve(cache.eTokenOut, type(uint256).max);
        IEVault(cache.eTokenOut).repay(amountOut, cache.accountOut);
    }

    function swapInternal(SwapCache memory cache, address swapHandler, ISwapHandler.SwapParams memory params) private returns (uint) {
        // Supply handler, for exact output amount transfered serves as an implicit amount in max.
        if (params.amountIn == type(uint256).max) params.amountIn = IEVault(cache.eTokenIn).maxWithdraw(cache.accountIn);
        IEVault(cache.eTokenIn).withdraw(params.amountIn, swapHandler, cache.accountIn);

        // Invoke handler
        ISwapHandler(swapHandler).executeSwap(params);

        // Verify output received, credit any returned input
        uint postBalanceIn = IERC20(params.underlyingIn).balanceOf(address(this));
        uint postBalanceOut = IERC20(params.underlyingOut).balanceOf(address(this));

        uint amountOutMin;
        if (params.mode == 0) {
            amountOutMin = params.amountOut;
        } else {
            require(params.amountOut > params.exactOutTolerance, "e/swap-hub/exact-out-tolerance");
            unchecked { amountOutMin = params.amountOut - params.exactOutTolerance; }
        }

        require(postBalanceOut >= cache.preBalanceOut + amountOutMin, "e/swap-hub/insufficient-output");
        // require(cache.preBalanceIn >= postBalanceIn, "e/swap-hub/positive-input");

        IERC20(params.underlyingIn).approve(cache.eTokenIn, type(uint256).max);
        IEVault(cache.eTokenIn).deposit(postBalanceIn, cache.accountIn);

        return postBalanceOut - cache.preBalanceOut;
    }

    function initSwap(address accountIn, address accountOut, address eTokenIn, address eTokenOut, ISwapHandler.SwapParams memory params) private view returns (SwapCache memory cache) {
        cache.accountIn = accountIn;
        cache.accountOut = accountOut;

        cache.eTokenIn = eTokenIn;
        cache.eTokenOut = eTokenOut;

        require(cache.eTokenIn != address(0), "e/swap-hub/in-market-not-activated");
        require(cache.eTokenOut != address(0), "e/swap-hub/out-market-not-activated");

        // probs not necessary
        cache.preBalanceIn = IERC20(params.underlyingIn).balanceOf(address(this));
        cache.preBalanceOut = IERC20(params.underlyingOut).balanceOf(address(this));
    }
}

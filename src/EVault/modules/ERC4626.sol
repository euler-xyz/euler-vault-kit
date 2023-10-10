// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseModule} from "../shared/BaseModule.sol";
import {IERC4626} from "../IEVault.sol";
import {console2} from "forge-std/Test.sol"; // DEV_MODE

abstract contract ERC4626Module is BaseModule, IERC4626 {

    /// @inheritdoc IERC4626
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
}

contract ERC4626 is ERC4626Module {
    constructor(address factory, address cvc) BaseModule(factory, cvc) {}
}
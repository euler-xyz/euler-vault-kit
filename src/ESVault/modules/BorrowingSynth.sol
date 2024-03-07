// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../EVault/modules/Borrowing.sol";

abstract contract BorrowingSynthModule is BorrowingModule {
    error NOT_SUPPORTTED();

    /// @inheritdoc BorrowingModule
    function loop(uint256 amount, address sharesReceiver) external virtual override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    /// @inheritdoc BorrowingModule
    function deloop(uint256 amount, address debtFrom) external virtual override returns (uint256) {
        revert NOT_SUPPORTTED();
    }

    function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal virtual override {

    }

    function pushTokens(MarketCache memory marketCache, address to, Assets amount) internal virtual override {

    }

}

contract BorrowingSynth is BorrowingSynthModule {
    constructor(Integrations memory integrations) Base(integrations) {}

    // function pullTokens(MarketCache memory marketCache, address from, Assets amount) internal override(BorrowingSynthModule, AssetTransfers) {
    //     BorrowingSynthModule.pullTokens(marketCache, from, amount);
    // }

    // function pushTokens(MarketCache memory marketCache, address to, Assets amount) internal override(BorrowingSynthModule, AssetTransfers) {
    //     BorrowingSynthModule.pushTokens(marketCache, to, amount);
    // }
}

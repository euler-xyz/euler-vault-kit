// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../src/EVault/modules/Token.sol";
import "../../src/EVault/shared/types/Types.sol";

contract TokenHarness is TokenModule {
    // for amount.toShares()
    using TypesLib for uint256;

    constructor(Integrations memory integrations) Base(integrations) {}

    function transferFromInternalHarnessed(address from, address to, uint256 amount) public returns (bool) {
        // This is similar to the body of Token.transferFromInternal
        // when it gets its arguments from Token.transfer.
        // It is not harnessed directly since Token.transferFromInternal is private
        // and we want to avoid munging.
        // This is used for the enforceCollateralTransfer function
        Shares shares = amount.toShares();
        if (from == to) revert E_SelfTransfer();
        decreaseAllowance(from, from, shares);
        transferBalance(from, to, shares);
        return true;
    }
}
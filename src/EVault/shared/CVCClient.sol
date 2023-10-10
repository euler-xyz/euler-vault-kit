// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "lib/euler-cvc/src/interfaces/ICreditVaultConnector.sol";

contract CVCClient {
    address immutable public cvc;

    constructor(address cvc_) {
        cvc = cvc_;
    }

    function CVCAuthenticate() internal view returns (address) {
        if (msg.sender == address(cvc)) {
            (address onBehalfOfAccount,) = ICVC(cvc).getExecutionContext(address(0));
            return onBehalfOfAccount;
        }

        return msg.sender;
    }
}

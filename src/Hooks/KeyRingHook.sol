// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import { BaseHook } from "./BaseHook.sol";

interface IKeyringCredentials {
    function checkCredential(address, uint32) external view returns (bool);
}

contract KeyRingHook is BaseHook {

    IKeyringCredentials public immutable keyring;
    uint32 internal immutable policyId;

    error KeyringCheckFailed();

    modifier checkKeyring() {
        if (!keyring.checkCredential(getAddressFromMsgData(), policyId)) {
            revert KeyringCheckFailed();
        }
        _;
    }

    constructor(address _keyring, uint32 _policyId) {
        keyring = IKeyringCredentials(_keyring);
        policyId = _policyId;
    }

    fallback() checkKeyring() external payable {
        // no-op
    }
}
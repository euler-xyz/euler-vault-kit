// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./EVault/IEVault.sol";
import "./EVault/modules/base/Base.sol";

library Utils {
    error E_EmptyError();

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revertBytes(data);
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revertBytes(data);
    }

    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), string(data));
    }

    function revertBytes(bytes memory errMsg) private pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert Base.E_EmptyError();
    }
}

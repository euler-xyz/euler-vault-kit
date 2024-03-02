// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {RevertBytes} from "./RevertBytes.sol";

library SafeERC20Lib {
    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in `initialize`.
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) RevertBytes.revertBytes(data);
    }

    // If no code exists under the token address, the function will succeed. EVault ensures this is not the case in `initialize`.
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) RevertBytes.revertBytes(data);
    }
}

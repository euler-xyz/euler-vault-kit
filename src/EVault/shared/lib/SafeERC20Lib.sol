// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "../../IEVault.sol";
import {RevertBytes} from "./RevertBytes.sol";

library SafeERC20Lib {
    // WARNING: Must be very careful with this modifier. It resets the free memory pointer
    // to the value it was when the function started. This saves gas if more memory will
    // be allocated in the future. However, if the memory will be later referenced
    // (for example because the function has returned a pointer to it) then you cannot
    // use this modifier.

    modifier FREEMEM() {
        uint256 origFreeMemPtr;

        assembly {
            origFreeMemPtr := mload(0x40)
        }

        _;

        /*
        assembly { // DEV_MODE: overwrite the freed memory with garbage to detect bugs
            let garbage := 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF
            for { let i := origFreeMemPtr } lt(i, mload(0x40)) { i := add(i, 32) } { mstore(i, garbage) }
        }
        */

        assembly {
            mstore(0x40, origFreeMemPtr)
        }
    }

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

    function callBalanceOf(IERC20 token, address account) internal view FREEMEM returns (uint256) {
        // We set a gas limit so that a malicious token can't eat up all gas and cause a liquidity check to fail.

        (bool success, bytes memory data) =
            address(token).staticcall{gas: 200000}(abi.encodeWithSelector(IERC20.balanceOf.selector, account));

        // If token's balanceOf() call fails for any reason, return 0. This prevents malicious tokens from causing liquidity checks to fail.
        // If the contract doesn't exist (maybe because selfdestructed), then data.length will be 0 and we will return 0.
        // Data length > 32 is allowed because some legitimate tokens append extra data that can be safely ignored.

        if (!success || data.length < 32) return 0;

        return abi.decode(data, (uint256));
    }
}

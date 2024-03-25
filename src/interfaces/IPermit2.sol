// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IPermit2 {
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

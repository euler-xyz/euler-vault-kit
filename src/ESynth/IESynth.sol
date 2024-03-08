// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IESynth {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}
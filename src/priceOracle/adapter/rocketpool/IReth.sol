// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

interface IReth {
    function getRethValue(uint256 _ethAmount) external view returns (uint256);
    function getEthValue(uint256 _rethAmount) external view returns (uint256);
}

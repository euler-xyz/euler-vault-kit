// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IProtocolConfig {
    function isValidInterestFee(address vault, uint16 interestFee) external view returns (bool);

    function feeConfig(address vault) external view returns (address protocolFeeReceiver, uint16 protocolFeeShare);
}

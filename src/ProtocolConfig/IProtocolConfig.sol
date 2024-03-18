// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IProtocolConfig {
    /**
     * @notice check if a vault's interest fee is valid
     * @dev an interest fee is considered valid only when it is greater than or equal the min interest fee and less than or equal the max interest fee
     * @dev if a vault has a specific interest fee ranges set by admin, it will be used, otherwise the generic ones will bech checked against
     * @return bool true for valid, else false
     */
    function isValidInterestFee(address vault, uint16 interestFee) external view returns (bool);

    /**
     * @notice get protocol fee config for a certain vault
     * @dev if vault == address(0), the generic config will be returned
     * @return address protocol fee receiver
     * @return uint16 protocol fee share
     */
    function protocolFeeConfig(address vault) external view returns (address, uint16);

    /**
     * @notice get interest fee ranges for a certain vault
     * @dev if vault == address(0), the generic ranges will be returned
     * @return uint16 min interest fee
     * @return uint16 max interest fee
     */
    function interestFeeRange(address vault) external view returns (uint16, uint16);
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IProtocolConfig.sol";

contract ProtocolConfig is IProtocolConfig {   
    error E_OnlyAdmin();
    error E_InvalidVault();
    error E_InvalidReceiver();

    struct InterestFeeRange {
        bool exists;
        uint16 minInterestFee;
        uint16 maxInterestFee;
    }

    struct ProtocolFeeConfig {
        bool exists;
        address feeReceiver;
        uint16 protocolFeeShare;
    }

    /// @dev admin address
    address admin;
    /// @dev protocol fee receiver
    address feeReceiver;

    /// @dev min interest fee, applied to all vault, unless a vault has a configured fee ranges by admin
    uint16 minInterestFee;
    /// @dev max interest fee, applied to all vault, unless a vault has a configured fee ranges by admin
    uint16 maxInterestFee;
    /// @dev protocol fee share, applied to all vault, unless vault has a configured protocol fee config by admin
    uint16 protocolFeeShare;

    /// @dev mapping of vault address to it's interest fee range
    mapping(address vault => InterestFeeRange) internal _interestFeeRanges;
    /// @dev mapping of vault address to it's protocol fee config
    mapping(address vault => ProtocolFeeConfig) internal _protocolFeeConfig;

    /// @dev events
    event SetMinInterestFee(uint256 oldMinInterestFee, uint256 newMinInterestFee);
    event SetMaxInterestFee(uint256 oldMaxInterestFee, uint256 newMaxInterestFee);
    event SetFeeReceiver(address indexed oldFeeReceiver, address indexed newFeeReceiver);
    event SetInterestFeeRange(address indexed vault, bool exists, uint16 minInterestFee, uint16 maxInterestFee);
    event SetFeeConfigSetting(address indexed ault, bool exists, address indexed feeReceiver, uint256 protocolFeeShare);
    
    /**
     * @dev constructor
     * @param admin_ admin's address
     * @param feeReceiver_ the address of the protocol fee receiver
     */
    constructor(address admin_, address feeReceiver_) {
        admin = admin_;
        feeReceiver = feeReceiver_;

        minInterestFee = 1e4 / 100;
        maxInterestFee = 1e4 * 50 / 100;
        protocolFeeShare = 0.1e4;
    }

    /// @inheritdoc IProtocolConfig
    function isValidInterestFee(address vault, uint16 interestFee) external view returns (bool) {
        InterestFeeRange memory range = _interestFeeRanges[vault];

        if (range.exists) {
            return interestFee >= range.minInterestFee && interestFee <= range.maxInterestFee;
        }

        return interestFee >= minInterestFee && interestFee <= maxInterestFee;
    }

    /// @inheritdoc IProtocolConfig
    function protocolFeeConfig(address vault) external view returns (address, uint16) {
        ProtocolFeeConfig memory config = _protocolFeeConfig[vault];

        if (config.exists) {
            return (config.feeReceiver, config.protocolFeeShare);
        }

        return (feeReceiver, protocolFeeShare);
    }

    /// @inheritdoc IProtocolConfig
    function interestFeeRanges(address vault) external view returns (uint16, uint16) {
        InterestFeeRange memory ranges = _interestFeeRanges[vault];

        if (ranges.exists) {
            return (ranges.minInterestFee, ranges.maxInterestFee);
        }

        return (minInterestFee, maxInterestFee);
    }

    // Admin functions

    /// @dev modifier to check if sender is admin address
    modifier onlyAdmin() {
        if(msg.sender != admin) revert E_OnlyAdmin();

        _;
    }

    /**
     * @notice set protocol fee receiver
     * @dev can only be called by admin
     * @param newReceiver new receiver address
     */
    function setFeeReceiver(address newReceiver) external onlyAdmin {
        if(newReceiver == address(0)) revert E_InvalidReceiver();

        emit SetFeeReceiver(feeReceiver, newReceiver);
        
        feeReceiver = newReceiver;
    }

    /**
     * @notice set generic min intereset fee
     * @dev can only be called by admin
     * @param minInterestFee_ new min interest fee
     */
    function setMinInterestFee(uint16 minInterestFee_) external onlyAdmin {
        emit SetMinInterestFee(minInterestFee_, minInterestFee);

        minInterestFee = minInterestFee_;
    }

    /**
     * @notice set generic max intereset fee
     * @dev can only be called by admin
     * @param maxInterestFee_ new max interest fee
     */
    function setMaxInterestFee(uint16 maxInterestFee_) external onlyAdmin {
        emit SetMaxInterestFee(maxInterestFee_, maxInterestFee);

        maxInterestFee = maxInterestFee_;
    }

    /**
     * @notice set interest fee range for specific vault
     * @dev can only be called by admin
     * @param vault vault's address
     * @param exists_ a boolean to set or unset the ranges. When false, the generic ranges will be used for the vault
     * @param minInterestFee_ min interest fee
     * @param maxInterestFee_ max interest fee
     */
    function setInterestFeeRange(address vault, bool exists_, uint16 minInterestFee_, uint16 maxInterestFee_) external onlyAdmin {
        if(vault == address(0)) revert E_InvalidVault();

        _interestFeeRanges[vault] = InterestFeeRange({
            exists: exists_,
            minInterestFee: minInterestFee_,
            maxInterestFee: maxInterestFee_
        });

        emit SetInterestFeeRange(vault, exists_, minInterestFee_, maxInterestFee_);
    }

    /**
     * @notice set protocol fee config for specific vault
     * @dev can only be called by admin
     * @param vault vault's address
     * @param exists_ a boolean to set or unset the config. When false, the generic config will be used for the vault
     * @param feeReceiver_ fee receiver address
     * @param protocolFeeShare_ fee share
     */
    function setFeeConfigSetting(address vault, bool exists_, address feeReceiver_, uint16 protocolFeeShare_) external onlyAdmin {
        if(vault == address(0)) revert E_InvalidVault();

        _protocolFeeConfig[vault] = ProtocolFeeConfig({
            exists: exists_,
            feeReceiver: feeReceiver_,
            protocolFeeShare: protocolFeeShare_
        });

        emit SetFeeConfigSetting(vault, exists_, feeReceiver_, protocolFeeShare_);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IProtocolConfig.sol";
import "../EVault/shared/Constants.sol";

contract ProtocolConfig is IProtocolConfig {
    uint16 constant MIN_INTEREST_FEE = 0.01e4;
    uint16 constant MAX_INTEREST_FEE = 0.5e4;
    uint16 constant PROTOCOL_FEE_SHARE = 0.1e4;

    struct InterestFeeRange {
        bool exists;
        uint16 minInterestFee;
        uint16 maxInterestFee;
    }

    struct FeeConfigSetting {
        bool exists;
        address feeReceiver;
        uint16 protocolFeeShare;
    }

    address admin;
    address feeReceiver;
    mapping(address vault => InterestFeeRange) interestFeeRanges;
    mapping(address vault => FeeConfigSetting) feeConfigSettings;

    constructor(address admin_, address feeReceiver_) {
        admin = admin_;
        feeReceiver = feeReceiver_;
        // TODO emit
    }

    function isValidInterestFee(address vault, uint16 interestFee) external view returns (bool) {
        InterestFeeRange memory range = interestFeeRanges[vault];

        if (range.exists) {
            return interestFee >= range.minInterestFee && interestFee <= range.maxInterestFee;
        }

        return interestFee >= MIN_INTEREST_FEE && interestFee <= MAX_INTEREST_FEE;
    }

    function feeConfig(address vault) external view returns (address, uint16) {
        FeeConfigSetting memory settings = feeConfigSettings[vault];

        if (settings.exists) {
            return (settings.feeReceiver, settings.protocolFeeShare);
        }

        return (feeReceiver, PROTOCOL_FEE_SHARE);
    }

    // Admin functions

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    function setFeeReceiver(address newReceiver) external onlyAdmin {
        require(newReceiver != address(0), "bad address");
        feeReceiver = newReceiver;
    }

    function setInterestFeeRange(address market, bool exists_, uint16 minInterestFee_, uint16 maxInterestFee_) external onlyAdmin {
        interestFeeRanges[market] = InterestFeeRange({
            exists: exists_,
            minInterestFee: minInterestFee_,
            maxInterestFee: maxInterestFee_
        });
    }

    function setFeeConfigSetting(address market, bool exists_, address feeReceiver_, uint16 protocolFeeShare_) external onlyAdmin {
        feeConfigSettings[market] = FeeConfigSetting({
            exists: exists_,
            feeReceiver: feeReceiver_,
            protocolFeeShare: protocolFeeShare_
        });
    }
}

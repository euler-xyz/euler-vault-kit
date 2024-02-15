// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../IProtocolConfig.sol";
import "../EVault/shared/Constants.sol";

contract ProtocolConfig is IProtocolConfig {
    address admin;
    address feeReceiver;

    uint256 constant MIN_INTEREST_FEE = 0.01 * 60_000; // TODO
    uint256 constant PROTOCOL_FEE_SHARE = 0.1 * 1e18;

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admim");
        _;
    }

    constructor(address admin_, address feeReceiver_) {
        admin = admin_;
        feeReceiver = feeReceiver_;
        // TODO emit
    }

    function isValidInterestFee(address, uint16 interestFee) external pure returns (bool) {
        return interestFee >= MIN_INTEREST_FEE && interestFee <= INTEREST_FEE_SCALE;
    }

    function feeConfig(address) external view returns (address, uint256) {
        return (feeReceiver, PROTOCOL_FEE_SHARE);
    }

    function skimConfig(address) external view returns (address, address) {
        return (admin, feeReceiver);
    }

    function setFeeReceiver(address newReceiver) external onlyAdmin {
        require(newReceiver != address(0), "bad address");
        feeReceiver = newReceiver;
    }
}

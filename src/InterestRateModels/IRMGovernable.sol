// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./IIRM.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title IRMGovernable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Implementaion on an interest rate model, which can be set by the owner of this contract
contract IRMGovernable is IIRM, Ownable {
    uint256 public immutable maxRate;
    uint256 public rate;

    error RateExceedsMaxRate();
    
    constructor(uint256 maxRate_, uint256 initialRate) Ownable(msg.sender) {
        maxRate = maxRate_;
        initialRate = rate;
    }

    function setRate(uint256 newRate) external onlyOwner {
        if (newRate > maxRate) {
            revert RateExceedsMaxRate();
        }
        rate = newRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address, uint256, uint256)
        external
        view
        override
        returns (uint256)
    {
        return rate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address, uint256, uint256)
        external
        view
        override
        returns (uint256)
    {
        return rate;
    }
}

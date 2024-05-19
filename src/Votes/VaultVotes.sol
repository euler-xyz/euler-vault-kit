// SPDX-License-Identifier: GPL-2.0-or-later

import {IBalanceTracker} from "../interfaces/IBalanceTracker.sol";
import {Votes, EIP712} from "openzeppelin-contracts/governance/utils/Votes.sol";

pragma solidity ^0.8.0;

contract VaultVotes is IBalanceTracker, Votes {
    mapping(address => uint256) public votingUnitsOf;

    address public vault;

    constructor(address vault_, string memory name, string memory version) EIP712(name, version) {
        vault = vault_;
    }

    function balanceTrackerHook(address account, uint256 newAccountBalance, bool forfeitRecentReward) external {
        require(msg.sender == vault, "VaultVotes: caller is not the vault");
        uint256 votingUnits = votingUnitsOf[account];

        if (newAccountBalance > votingUnits) {
            uint256 additionalVotingUnits = newAccountBalance - votingUnits;
            _transferVotingUnits(address(0), account, additionalVotingUnits);
            votingUnitsOf[account] = newAccountBalance;
        } else if (newAccountBalance < votingUnits) {
            uint256 removedVotingUnits = votingUnits - newAccountBalance;
            _transferVotingUnits(account, address(0), removedVotingUnits);
            votingUnitsOf[account] = newAccountBalance;
        }
    }


    function _getVotingUnits(address account) internal view override returns (uint256) {
        return votingUnitsOf[account];
    }
}

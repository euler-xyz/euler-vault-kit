// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import {RedstoneCoreOracle} from "src/adapter/redstone/RedstoneCoreOracle.sol";

contract RedstoneCoreOracleHarness is RedstoneCoreOracle {
    uint256 price;

    constructor(address _base, address _quote, bytes32 _feedId, uint32 _maxStaleness)
        RedstoneCoreOracle(_base, _quote, _feedId, _maxStaleness)
    {}

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getOracleNumericValueFromTxMsg(bytes32) internal view override returns (uint256) {
        return price;
    }
}

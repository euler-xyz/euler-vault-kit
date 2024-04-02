// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "src/EVault/IEVault.sol";

contract MockPriceOracle {
    error PO_BaseUnsupported();
    error PO_QuoteUnsupported();
    error PO_Overflow();
    error PO_NoPath();

    mapping(address base => mapping(address quote => uint256)) prices;

    function name() external pure returns (string memory) {
        return "MockPriceOracle";
    }

    function getQuote(uint256 amount, address base, address quote) public view returns (uint256 out) {
        uint256 price = prices[base][quote];
        (bool success,) = base.staticcall(abi.encodeCall(IERC4626.asset, ()));
        if (base.code.length > 0 && success) amount = IEVault(base).convertToAssets(amount);

        return amount * price / 1e18;
    }

    function getQuotes(uint256 amount, address base, address quote)
        external
        view
        returns (uint256 bidOut, uint256 askOut)
    {
        bidOut = askOut = getQuote(amount, base, quote);
    }

    ///// Mock functions

    function setPrice(address base, address quote, uint256 price) external {
        prices[base][quote] = price;
    }

    function testExcludeFromCoverage() public pure {
        return;
    }
}

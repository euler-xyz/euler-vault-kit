// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface IPriceOracle {
    function name() external view returns (string memory);

    function getQuote(uint256 amount, address base, address quote) external view returns (uint256 out);
    function getQuotes(uint256 amount, address base, address quote)
        external
        view
        returns (uint256 bidOut, uint256 askOut);

    error PO_BaseUnsupported();
    error PO_QuoteUnsupported();
    error PO_Overflow();
    error PO_NoPath();
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../IEVault.sol";

import "./MarketStorage.sol";
import "./Snapshot.sol";
import "./UserStorage.sol";
import "./LTVConfig.sol";

import "./Shares.sol";
import "./Assets.sol";
import "./Owed.sol";
import "./ConfigAmount.sol";
import "./Operations.sol";
import "./AmountCap.sol";
import "./LTVType.sol";

type Shares is uint112;

type Assets is uint112;

type Owed is uint144;

type AmountCap is uint16;

type ConfigAmount is uint16;

type Operations is uint32;

using SharesLib for Shares global;
using {
    addShares as +, subShares as -, eqShares as ==, neqShares as !=, gtShares as >, ltShares as <
} for Shares global;

using AssetsLib for Assets global;
using {
    addAssets as +, subAssets as -, eqAssets as ==, neqAssets as !=, gtAssets as >, ltAssets as <, lteAssets as <=
} for Assets global;

using OwedLib for Owed global;
using {addOwed as +, subOwed as -, eqOwed as ==, neqOwed as !=, gtOwed as >, ltOwed as <} for Owed global;

using ConfigAmountLib for ConfigAmount global;
using {addConfigAmount as +, subConfigAmount as -, gtConfigAmount as >, ltConfigAmount as <} for ConfigAmount global; 

using AmountCapLib for AmountCap global;
using OperationsLib for Operations global;

library TypesLib {
    function toShares(uint256 amount) internal pure returns (Shares) {
        if (amount > MAX_SANE_AMOUNT) revert Errors.E_AmountTooLargeToEncode();
        return Shares.wrap(uint112(amount));
    }

    function toAssets(uint256 amount) internal pure returns (Assets) {
        if (amount > MAX_SANE_AMOUNT) revert Errors.E_AmountTooLargeToEncode();
        return Assets.wrap(uint112(amount));
    }

    function toOwed(uint256 amount) internal pure returns (Owed) {
        if (amount > MAX_SANE_DEBT_AMOUNT) revert Errors.E_DebtAmountTooLargeToEncode();
        return Owed.wrap(uint144(amount));
    }

    function toConfigAmount(uint16 amount) internal pure returns (ConfigAmount) {
        ConfigAmountLib.validate(amount);
        return ConfigAmount.wrap(amount);
    }
}

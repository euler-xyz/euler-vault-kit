// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../Errors.sol";
import "../Constants.sol";
import {Storage} from "../Storage.sol";

import "./BitField.sol";
import "./Shares.sol";
import "./Assets.sol";
import "./Owed.sol";
import "./Fees.sol";
import "./UserStorage.sol";
import "./AmountCap.sol";
import "./LTVConfig.sol";

type BitField is uint32;

type Shares is uint112;

type Assets is uint112;

type Owed is uint144;

type Fees is uint96;

type AmountCap is uint16;

using BitFieldLib for BitField global;
using SharesLib for Shares global;
using {
    addShares as +, subShares as -, eqShares as ==, neqShares as !=, gtShares as >, ltShares as <
} for Shares global;

using AssetsLib for Assets global;
using {
    addAssets as +, subAssets as -, eqAssets as ==, neqAssets as !=, gtAssets as >, ltAssets as <
} for Assets global;

using OwedLib for Owed global;
using {addOwed as +, subOwed as -, eqOwed as ==, neqOwed as !=, gtOwed as >, ltOwed as <} for Owed global;

using FeesLib for Fees global;
using {addFees as +} for Fees global;

using AmountCapLib for AmountCap global;

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

    function toFees(uint256 amount) internal pure returns (Fees) {
        if (amount > MAX_SANE_SMALL_AMOUNT) revert Errors.E_SmallAmountTooLargeToEncode();
        return Fees.wrap(uint96(amount));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCUtil, IEVC} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ESynth} from "./ESynth.sol";

contract PegStabilityModule is EVCUtil {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_SCALE = 100_00;
    uint256 public constant PRICE_SCALE = 1e18;

    ESynth public immutable synth;
    IERC20 public immutable underlying;
    uint256 public immutable conversionPrice; // 1e18 = 1 SYNTH == 1 UNDERLYING, 0.01e18 = 1 SYNTH == 0.01 UNDERLYING

    uint256 public immutable TO_UNDERLYING_FEE;
    uint256 public immutable TO_SYNTH_FEE;

    error E_ZeroAddress();
    error E_FeeExceedsBPS();

    constructor(
        address _evc,
        address _synth,
        address _underlying,
        uint256 toUnderlyingFeeBPS,
        uint256 toSynthFeeBPS,
        uint256 _conversionPrice
    ) EVCUtil(_evc) {
        if (toUnderlyingFeeBPS > BPS_SCALE || toSynthFeeBPS > BPS_SCALE) {
            revert E_FeeExceedsBPS();
        }

        if (_evc == address(0) || _synth == address(0) || _underlying == address(0)) {
            revert E_ZeroAddress();
        }

        synth = ESynth(_synth);
        underlying = IERC20(_underlying);
        TO_UNDERLYING_FEE = toUnderlyingFeeBPS;
        TO_SYNTH_FEE = toSynthFeeBPS;
        conversionPrice = _conversionPrice;
    }

    function swapToUnderlyingGivenIn(uint256 amountIn, address receiver) external returns (uint256) {
        uint256 amountOut = quoteToUnderlyingGivenIn(amountIn);

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountOut;
    }

    function swapToUnderlyingGivenOut(uint256 amountOut, address receiver) external returns (uint256) {
        uint256 amountIn = quoteToUnderlyingGivenOut(amountOut);

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountIn;
    }

    function swapToSynthGivenIn(uint256 amountIn, address receiver) external returns (uint256) {
        uint256 amountOut = quoteToSynthGivenIn(amountIn);

        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountOut;
    }

    function swapToSynthGivenOut(uint256 amountOut, address receiver) external returns (uint256) {
        uint256 amountIn = quoteToSynthGivenOut(amountOut);

        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountIn;
    }

    function quoteToUnderlyingGivenIn(uint256 amountIn) public view returns (uint256) {
        return amountIn * (BPS_SCALE - TO_UNDERLYING_FEE) / BPS_SCALE * conversionPrice / PRICE_SCALE;
    }

    function quoteToUnderlyingGivenOut(uint256 amountOut) public view returns (uint256) {
        return amountOut * BPS_SCALE / (BPS_SCALE - TO_UNDERLYING_FEE) * PRICE_SCALE / conversionPrice;
    }

    function quoteToSynthGivenIn(uint256 amountIn) public view returns (uint256) {
        return amountIn * (BPS_SCALE - TO_SYNTH_FEE) / BPS_SCALE * PRICE_SCALE / conversionPrice;
    }

    function quoteToSynthGivenOut(uint256 amountOut) public view returns (uint256) {
        return amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE) * conversionPrice / PRICE_SCALE;
    }
}

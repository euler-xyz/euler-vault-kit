// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IESynth} from "../ESynth/IESynth.sol";
import {EVCUtil, IEVC} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract PSM is EVCUtil {
    using SafeERC20 for IERC20;

    uint public constant BPS_SCALE = 10000;

    IESynth public immutable synth;
    IERC20 public immutable underlying;

    uint public immutable TO_UNDERLYING_FEE;
    uint public immutable TO_SYNTH_FEE;

    error E_TranferFailed();

    constructor(address _evc, address _synth, address _underlying, uint toUnderlyingFeeBPS, uint toSynthFeeBPS) EVCUtil(IEVC(_evc)) {
        synth = IESynth(_synth);
        underlying = IERC20(_underlying);
        TO_UNDERLYING_FEE = toUnderlyingFeeBPS;
        TO_SYNTH_FEE = toSynthFeeBPS;
    }


    function swapToUnderlyingGivenIn(uint amountIn, address receiver) external returns (uint amountOut) {
        amountOut = quoteToUnderlyingGivenIn(amountIn);

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountOut;
    }

    function swapToUnderlyingGivenOut(uint amountOut, address receiver) external returns (uint amountIn) {
        amountIn = quoteToUnderlyingGivenOut(amountOut);

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountIn;
    }

    function swapToSynthGivenIn(uint256 amountIn, address receiver) external returns (uint amountOut) {
        amountOut = quoteToSynthGivenIn(amountIn);

        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountOut;
    }

    function swapToSynthGivenOut(uint amountOut, address receiver) external returns (uint amountIn) {
        amountIn = quoteToSynthGivenOut(amountOut);
        
        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountIn;
    }

    function quoteToUnderlyingGivenIn(uint amountIn) public view returns (uint amountOut) {
        amountOut = amountIn * (BPS_SCALE - TO_UNDERLYING_FEE) / BPS_SCALE;
        return amountOut;
    }

    function quoteToUnderlyingGivenOut(uint amountOut) public view returns (uint amountIn) {
        amountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_UNDERLYING_FEE);
        return amountIn;
    }

    function quoteToSynthGivenIn(uint amountIn) public view returns (uint amountOut) {
        amountOut = amountIn * (BPS_SCALE - TO_SYNTH_FEE) / BPS_SCALE;
        return amountOut;
    }

    function quoteToSynthGivenOut(uint amountOut) public view returns (uint amountIn) {
        amountIn = amountOut * BPS_SCALE / (BPS_SCALE - TO_SYNTH_FEE);
        return amountIn;
    }

}
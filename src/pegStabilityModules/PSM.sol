// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IESynth} from "../ESynth/IESynth.sol";
import {EVCUtil, IEVC} from "ethereum-vault-connector/utils/EVCUtil.sol";

contract PSM is EVCUtil {
    uint public constant BPS_SCALE = 10000;

    IESynth public immutable synth;
    uint public immutable TO_UNDERLYING_FEE;
    uint public immutable TO_SYNTH_FEE;

    error E_TranferFailed();

    constructor(address _evc, address _synth, uint toUnderlyingFeeBPS, uint toSynthFeeBPS) EVCUtil(IEVC(_evc)) {
        synth = IESynth(_synth);
        TO_UNDERLYING_FEE = toUnderlyingFeeBPS;
        TO_SYNTH_FEE = toSynthFeeBPS;
    }


    function swapToUnderlyingGivenIn(uint amountIn, address receiver) external payable returns (uint amountOut) {
        amountOut = quoteToUnderlyingGivenIn(amountIn);
        synth.burn(_msgSender(), amountIn);

        (bool success, ) = receiver.call{value: amountOut}("");
        if(!success) revert E_TranferFailed();

        return amountOut;
    }

    function swapToUnderlyingGivenOut(uint amountOut, address receiver) external payable returns (uint amountIn) {
        amountIn = quoteToUnderlyingGivenOut(amountOut);
        synth.burn(_msgSender(), amountIn);

        (bool success, ) = receiver.call{value: amountOut}("");
        if(!success) revert E_TranferFailed();

        return amountIn;
    }

    function swapToSynthGivenIn(address receiver) external payable returns (uint amountOut) {
        amountOut = quoteToSynthGivenIn(msg.value);
        synth.mint(receiver, amountOut);
        return amountOut;
    }

    function swapToSynthGivenOut(uint amountOut, address receiver) external payable returns (uint amountIn) {
        amountIn = quoteToSynthGivenOut(amountOut);
        
        // Will throw on overflow if msg.value is less than expected amount in
        uint delta = msg.value - amountIn;
        // return excess
        if (delta > 0) {
            (bool success, ) = _msgSender().call{value: delta}("");
            if(!success) revert E_TranferFailed();
        }

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
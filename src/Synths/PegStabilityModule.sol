// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {ESynth} from "./ESynth.sol";

/// @title PegStabilityModule
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice The PegStabilityModule is granted minting rights on the ESynth and must allow slippage-free conversion from
/// and to the underlying asset as per configured CONVERSION_PRICE. On deployment, the fee for swaps to synthetic asset
/// and to underlying asset are defined. These fees must accrue to the PegStabilityModule contract and can not be
/// withdrawn, serving as a permanent reserve to support the peg. Swapping to the synthetic asset is possible up to the
/// minting cap granted for the PegStabilityModule in the ESynth. Swapping to the underlying asset is possible up to the
/// amount of the underlying asset held by the PegStabilityModule.
contract PegStabilityModule is EVCUtil {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant BPS_SCALE = 100_00;
    uint256 public constant PRICE_SCALE = 1e18;

    /// @notice The synthetic asset.
    ESynth public immutable synth;
    /// @notice The underlying asset.
    IERC20 public immutable underlying;

    /// @notice The fee for swapping to the underlying asset in basis points.
    uint256 public immutable TO_UNDERLYING_FEE;
    /// @notice The fee for swapping to the synthetic asset in basis points.
    uint256 public immutable TO_SYNTH_FEE;
    /// @notice The conversion price between the synthetic and underlying asset.
    uint256 public immutable CONVERSION_PRICE;

    error E_ZeroAddress();
    error E_FeeExceedsBPS();
    error E_ZeroConversionPrice();

    /// @param _evc The address of the EVC.
    /// @param _synth The address of the synthetic asset.
    /// @param _underlying The address of the underlying asset.
    /// @param _toUnderlyingFeeBPS The fee for swapping to the underlying asset in basis points. eg: 100 = 1%
    /// @param _toSynthFeeBPS The fee for swapping to the synthetic asset in basis points. eg: 100 = 1%
    /// @param _conversionPrice The conversion price between the synthetic and underlying asset.
    /// @dev _conversionPrice = 10**underlyingDecimals corresponds to 1:1 peg
    /// @dev if underlying is 18 decimals, _conversionPrice = 1e18 corresponds to 1:1 peg
    /// @dev if underlying is  6 decimals, _conversionPrice = 1e6  corresponds to 1:1 peg
    constructor(
        address _evc,
        address _synth,
        address _underlying,
        uint256 _toUnderlyingFeeBPS,
        uint256 _toSynthFeeBPS,
        uint256 _conversionPrice
    ) EVCUtil(_evc) {
        if (_synth == address(0) || _underlying == address(0)) {
            revert E_ZeroAddress();
        }

        if (_toUnderlyingFeeBPS >= BPS_SCALE || _toSynthFeeBPS >= BPS_SCALE) {
            revert E_FeeExceedsBPS();
        }

        if (_conversionPrice == 0) {
            revert E_ZeroConversionPrice();
        }

        synth = ESynth(_synth);
        underlying = IERC20(_underlying);
        TO_UNDERLYING_FEE = _toUnderlyingFeeBPS;
        TO_SYNTH_FEE = _toSynthFeeBPS;
        CONVERSION_PRICE = _conversionPrice;
    }

    /// @notice Swaps the given amount of synth to underlying given an input amount of synth.
    /// @param amountIn The amount of synth to swap.
    /// @param receiver The address to receive the underlying.
    /// @return The amount of underlying received.
    function swapToUnderlyingGivenIn(uint256 amountIn, address receiver) external returns (uint256) {
        uint256 amountOut = quoteToUnderlyingGivenIn(amountIn);
        if (amountIn == 0 || amountOut == 0) {
            return 0;
        }

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountOut;
    }

    /// @notice Swaps the given amount of synth to underlying given an output amount of underlying.
    /// @param amountOut The amount of underlying to receive.
    /// @param receiver The address to receive the underlying.
    /// @return The amount of synth swapped.
    function swapToUnderlyingGivenOut(uint256 amountOut, address receiver) external returns (uint256) {
        uint256 amountIn = quoteToUnderlyingGivenOut(amountOut);
        if (amountIn == 0 || amountOut == 0) {
            return 0;
        }

        synth.burn(_msgSender(), amountIn);
        underlying.safeTransfer(receiver, amountOut);

        return amountIn;
    }

    /// @notice Swaps the given amount of underlying to synth given an input amount of underlying.
    /// @param amountIn The amount of underlying to swap.
    /// @param receiver The address to receive the synth.
    /// @return The amount of synth received.
    function swapToSynthGivenIn(uint256 amountIn, address receiver) external returns (uint256) {
        uint256 amountOut = quoteToSynthGivenIn(amountIn);
        if (amountIn == 0 || amountOut == 0) {
            return 0;
        }

        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountOut;
    }

    /// @notice Swaps the given amount of underlying to synth given an output amount of synth.
    /// @param amountOut The amount of synth to receive.
    /// @param receiver The address to receive the synth.
    /// @return The amount of underlying swapped.
    function swapToSynthGivenOut(uint256 amountOut, address receiver) external returns (uint256) {
        uint256 amountIn = quoteToSynthGivenOut(amountOut);
        if (amountIn == 0 || amountOut == 0) {
            return 0;
        }

        underlying.safeTransferFrom(_msgSender(), address(this), amountIn);
        synth.mint(receiver, amountOut);

        return amountIn;
    }

    /// @notice Quotes the amount of underlying given an input amount of synth.
    /// @param amountIn The amount of synth to swap.
    /// @return The amount of underlying received.
    function quoteToUnderlyingGivenIn(uint256 amountIn) public view returns (uint256) {
        return amountIn.mulDiv(
            (BPS_SCALE - TO_UNDERLYING_FEE) * CONVERSION_PRICE, BPS_SCALE * PRICE_SCALE, Math.Rounding.Floor
        );
    }

    /// @notice Quotes the amount of underlying given an output amount of synth.
    /// @param amountOut The amount of underlying to receive.
    /// @return The amount of synth swapped.
    function quoteToUnderlyingGivenOut(uint256 amountOut) public view returns (uint256) {
        return amountOut.mulDiv(
            BPS_SCALE * PRICE_SCALE, (BPS_SCALE - TO_UNDERLYING_FEE) * CONVERSION_PRICE, Math.Rounding.Ceil
        );
    }

    /// @notice Quotes the amount of synth given an input amount of underlying.
    /// @param amountIn The amount of underlying to swap.
    /// @return The amount of synth received.
    function quoteToSynthGivenIn(uint256 amountIn) public view returns (uint256) {
        return
            amountIn.mulDiv((BPS_SCALE - TO_SYNTH_FEE) * PRICE_SCALE, BPS_SCALE * CONVERSION_PRICE, Math.Rounding.Floor);
    }

    /// @notice Quotes the amount of synth given an output amount of underlying.
    /// @param amountOut The amount of synth to receive.
    /// @return The amount of underlying swapped.
    function quoteToSynthGivenOut(uint256 amountOut) public view returns (uint256) {
        return
            amountOut.mulDiv(BPS_SCALE * CONVERSION_PRICE, (BPS_SCALE - TO_SYNTH_FEE) * PRICE_SCALE, Math.Rounding.Ceil);
    }
}

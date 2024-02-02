// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./BaseIRM.sol";

interface ILidoOracle {
    function getLastCompletedReportDelta()
        external
        view
        returns (uint256 postTotalPooledEther, uint256 preTotalPooledEther, uint256 timeElapsed);
}

interface IStETH {
    function getFee() external view returns (uint16 feeBasisPoints);
}

contract IRMClassLido is BaseIRM {
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 constant MAX_ALLOWED_LIDO_INTEREST_RATE = 1e27 / SECONDS_PER_YEAR; // 100% APR
    uint256 constant LIDO_BASIS_POINT = 10000;
    address public immutable lidoOracle;
    address public immutable stETH;
    uint256 public immutable slope1;
    uint256 public immutable slope2;
    uint256 public immutable kink;

    struct IRMLidoStorage {
        uint72 baseRate;
        uint64 lastCalled;
    }

    constructor() {
        lidoOracle = 0x442af784A788A5bd6F42A01Ebe9F287a871243fb;
        stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

        // Base=Lido APY,  Kink(80%)=8% APY  Max=200% APY
        slope1 = 709783723;
        slope2 = 37689273223;
        kink = 3435973836;
    }

    function computeInterestRateImpl(address, address, uint32 utilisation) internal override returns (uint72) {
        uint256 ir = 0;
        if (utilisation > 0) {
            IRMLidoStorage storage irmLido;
            {
                bytes32 storagePosition = keccak256("euler.irm.class.lido");
                assembly {
                    irmLido.slot := storagePosition
                }
            }

            if (block.timestamp - irmLido.lastCalled > SECONDS_PER_DAY) {
                (bool successReport, bytes memory dataReport) =
                    lidoOracle.staticcall(abi.encodeWithSelector(ILidoOracle.getLastCompletedReportDelta.selector));
                (bool successFee, bytes memory dataFee) =
                    stETH.staticcall(abi.encodeWithSelector(IStETH.getFee.selector));

                // if the external contract calls unsuccessful, the base rate will be set to the last stored value
                if (successReport && successFee && dataReport.length >= (3 * 32) && dataFee.length >= 32) {
                    (uint256 postTotalPooledEther, uint256 preTotalPooledEther, uint256 timeElapsed) =
                        abi.decode(dataReport, (uint256, uint256, uint256));
                    uint16 lidoFee = abi.decode(dataFee, (uint16));

                    // do not support negative rebases
                    // assure Lido reward fee is not greater than LIDO_BASIS_POINT
                    uint256 baseRate = 0;
                    if (
                        preTotalPooledEther != 0 && timeElapsed != 0 && preTotalPooledEther < postTotalPooledEther
                            && lidoFee < LIDO_BASIS_POINT
                    ) {
                        unchecked {
                            baseRate = 1e27 * (postTotalPooledEther - preTotalPooledEther)
                                / (preTotalPooledEther * timeElapsed);

                            // reflect Lido reward fee
                            baseRate = baseRate * (LIDO_BASIS_POINT - lidoFee) / LIDO_BASIS_POINT;
                        }
                    }

                    // update the storage only if the Lido oracle call was successful
                    irmLido.baseRate = uint72(baseRate);
                    irmLido.lastCalled = uint64(block.timestamp);
                }
            }

            ir = uint72(irmLido.baseRate);

            // avoids potential overflow in subsequent calculations
            if (ir > MAX_ALLOWED_LIDO_INTEREST_RATE) {
                ir = MAX_ALLOWED_LIDO_INTEREST_RATE;
            }
        }

        if (utilisation <= kink) {
            ir += utilisation * slope1;
        } else {
            ir += kink * slope1;
            ir += slope2 * (utilisation - kink);
        }

        return uint72(ir);
    }
}

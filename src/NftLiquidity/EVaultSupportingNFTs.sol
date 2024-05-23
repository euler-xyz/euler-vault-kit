// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../EVault/Evault.sol";
import "../EVault/shared/types/VaultCache.sol";
import "../EVault/shared/Constants.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract EVaultSupportingNFTs is EVault {

    bytes32 constant COLLATERAL_TYPE_STORAGE_POSITION = keccak256("euler.collateralType");

    uint256 public constant TOKEN_COLLATERAL_TYPE = 0;
    uint256 public constant NFT_COLLATERAL_TYPE = 1;

    struct CollateralTypeStorage {
        mapping(address => uint256) collateralType;
    }

    constructor(Integrations memory integrations, DeployedModules memory modules) EVault(integrations, modules) {}

    function setCollateralType(address collateral, uint256 collateralType) public governorOnly {
        CollateralTypeStorage storage store = loadCollateralTypeStorage();

        if(collateralType != TOKEN_COLLATERAL_TYPE || collateralType !=  NFT_COLLATERAL_TYPE) {
            revert("no bueno");
        }

        store.collateralType[collateral] = collateralType;
    }

    function loadCollateralTypeStorage() internal pure returns (CollateralTypeStorage storage store) {
        bytes32 position = COLLATERAL_TYPE_STORAGE_POSITION;
        assembly {
            store.slot := position
        }
    }

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance)
        public
        virtual
        override
        nonReentrant
    {
        (VaultCache memory vaultCache, address liquidator) = initOperation(OP_LIQUIDATE, CHECKACCOUNT_CALLER);
        CollateralTypeStorage storage store = loadCollateralTypeStorage();

        LiquidationCache memory liqCache =
            calculateLiquidation(vaultCache, liquidator, violator, collateral, repayAssets);

        
        // Default behavior when an a ERC20 token gets liquidated
        uint256 collateralType = store.collateralType[collateral];
        if(collateralType == TOKEN_COLLATERAL_TYPE) {
            executeLiquidation(vaultCache, liqCache, minYieldBalance);
        } else {
            // TODO consider if only full liquidations should be allowed when an NFT is used as collateral and double check rounding in calculations
            executeLiquidationNFT(vaultCache, liqCache, minYieldBalance);
        }


    }

     function executeLiquidationNFT(VaultCache memory vaultCache, LiquidationCache memory liqCache, uint256 minYieldBalance)
        internal
    {
        // Check minimum yield.

        if (minYieldBalance > liqCache.yieldBalance) revert E_MinYield();

        // Handle repay: liquidator takes on violator's debt:

        transferBorrow(vaultCache, liqCache.violator, liqCache.liquidator, liqCache.repay);

        // Handle yield: liquidator receives violator's collateral

        // Impersonate violator on the EVC to seize collateral. The yield transfer will trigger a health check on the violator's
        // account, which should be forgiven, because the violator's account is not guaranteed to be healthy after liquidation.
        // This operation is safe, because:
        // 1. `liquidate` function is enforcing that the violator is not in deferred checks state,
        //    therefore there were no prior batch operations that could have registered a health check,
        //    and if the check is present now, it must have been triggered by the enforced transfer.
        // 2. Only collaterals with initialized LTV settings can be liquidated and they are assumed to be audited
        //    to have safe transfer methods, which make no external calls. In other words, yield transfer will not
        //    have any side effects, which would be wrongly forgiven.
        // 3. Any additional operations on violator's account in a batch will register the health check again, and it
        //    will be executed normally at the end of the batch.

        if (liqCache.yieldBalance > 0) {
            // enforceCollateralTransfer(
            //     liqCache.collateral, liqCache.yieldBalance, liqCache.violator, liqCache.liquidator
            // );

            // NFT specific override 
            // TODO allow tokenIds to be passed along
            evc.controlCollateral(collateral, from, 0, abi.encodeCall(IERC721.transferFrom, (collateral, receiver, )));


            forgiveAccountStatusCheck(liqCache.violator);
        }

        // Handle debt socialization

        if (
            vaultCache.configFlags.isNotSet(CFG_DONT_SOCIALIZE_DEBT) && liqCache.liability > liqCache.repay
                && checkNoCollateral(liqCache.violator, liqCache.collaterals)
        ) {
            Assets owedRemaining = liqCache.liability.subUnchecked(liqCache.repay);
            decreaseBorrow(vaultCache, liqCache.violator, owedRemaining);

            // decreaseBorrow emits Repay without any assets entering the vault. Emit Withdraw from and to zero address to cover the missing amount for offchain trackers.
            emit Withdraw(liqCache.liquidator, address(0), address(0), owedRemaining.toUint(), 0);
            emit DebtSocialized(liqCache.violator, owedRemaining.toUint());
        }

        emit Liquidate(
            liqCache.liquidator, liqCache.violator, liqCache.collateral, liqCache.repay.toUint(), liqCache.yieldBalance
        );
    }
}


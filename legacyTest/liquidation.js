const et = require('./lib/eTestLib');

const NO_EXPIRY = et.BN(2).pow(40).sub(2)


const getRiskAdjustedValue = (amount, price, factor) => amount.mul(et.eth(price)).div(et.eth(1)).mul(et.eth(factor)).div(et.eth(1))

et.testSet({
    desc: "liquidation",

    preActions: ctx => {
        let actions = [];

        actions.push({ action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', });

        actions.push({ action: 'setLTV', collateral: 'WETH', liability: 'TST', cf: 0.3 });
        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 });

        // wallet is lender and liquidator

        actions.push({ send: 'tokens.TST.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eTST.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ send: 'tokens.WETH.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.WETH.approve', args: [ctx.contracts.eVaults.eWETH.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eWETH.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eTST3.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ send: 'tokens.TST2.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });

        // wallet2 is borrower/violator

        actions.push({ send: 'tokens.TST2.mint', args: [ctx.wallet2.address, et.eth(100)], });
        actions.push({ from: ctx.wallet2, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        actions.push({ send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(100)], });
        actions.push({ from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });

        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(100), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },);

        // wallet3 is innocent bystander

        actions.push({ send: 'tokens.TST.mint', args: [ctx.wallet3.address, et.eth(100)], });
        actions.push({ from: ctx.wallet3, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(30), ctx.wallet3.address], });
        actions.push({ send: 'tokens.TST2.mint', args: [ctx.wallet3.address, et.eth(100)], });
        actions.push({ from: ctx.wallet3, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [et.eth(18), ctx.wallet3.address], });
        actions.push({ from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST2.address], },);
        // initial prices

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.2', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.4', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '2.2', });

        return actions;
    },
})



.test({
    desc: "no violation",
    actions: ctx => [

        // Liquidator not in controller

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address, 1, 0], expectError: 'E_ControllerDisabled', },

        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address, 1, 0], expectError: 'E_BadCollateral', },

        // User not in collateral:

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.3 },
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address, 1, 0], expectError: 'E_CollateralDisabled', },

        // User healthy:

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address,  1, 0], expectError: 'E_ExcessiveRepayAmount', },
        // no-op
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address,  0, 0], onLogs: logs => {
            const log = logs.find(l => l.name === 'Liquidate');
            et.equals(log.args.repayAssets, 0);
            et.equals(log.args.yieldBalance, 0);
        }},

        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 100 },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 5 },


        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], onResult: r => {
            et.equals(r.maxYield, 0);
            et.equals(r.maxRepay, 0);
        }},
    ],
})




.test({
    desc: "self liquidation",
    actions: ctx => [
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address, 1, 0], expectError: 'E_SelfLiquidation', },
    ],
})



.test({
    desc: "basic full liquidation",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
        }, },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue);
            et.equals(r.collateralValue / r.liabilityValue, 0.96, 0.001);
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              ctx.stash.maxRepay = r.maxRepay;
              ctx.stash.maxYield = r.maxYield;
          },
        },

        // If repay amount is 0, it's a no-op
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },

        // Nothing changed:
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: async r => {
              et.equals(r.maxRepay, ctx.stash.maxRepay);
              et.equals(r.maxYield, ctx.stash.maxYield);

              const yieldAssets = await ctx.contracts.eVaults.eTST2.convertToAssets(r.maxYield);
              const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST2.address, ctx.contracts.tokens.WETH.address)
              const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST.address, ctx.contracts.tokens.WETH.address)
              et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
          },
        },

        // Try to repay too much
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay.add(1), 0], expectError: 'E_ExcessiveRepayAmount'},

        // minYield too low
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, () => ctx.stash.maxYield.add(1)], expectError: 'E_MinYield', },

        // Successful liquidation

        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: [0, '0.000000000001'] },
        // repay full debt
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: () => ctx.stash.maxRepay, },

        { action: 'snapshot'},
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },
        // max uint is equivalent to maxRepay
        { action: 'revert'},
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, et.MaxUint256, 0], },
        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '0.000000000001'], },

        // reserves:
        { call: 'eVaults.eTST.accumulatedFeesAssets', onResult: (r) => ctx.stash.reserves = r, },

        // violator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], assertEql: [] },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => [et.units(100).sub(ctx.stash.maxYield), '0.0000000000011'], },

        // Confirming innocent bystander's balance not changed:

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], equals: [et.eth('30'), 0.01], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet3.address], equals: [et.eth('18'), 0.01]},
    ],
})



.test({
    desc: "partial liquidation",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              ctx.stash.maxRepay = r.maxRepay.div(4);
              ctx.stash.maxYield = ctx.stash.maxRepay.mul(r.maxYield).div(r.maxRepay);
          },
        },
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            ctx.stash.origHealth = r.collateralValue / r.liabilityValue;
        }, },


        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        // Yield is proportional to how much was repaid
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '.0000000000001'], },

        // reserves:
        { call: 'eVaults.eTST.accumulatedFeesAssets', onResult: (r) => ctx.stash.reserves = r, },

        // violator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: () => [et.units(5).sub(ctx.stash.maxRepay).add(ctx.stash.reserves), '0.000000000001'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address],  equals: () => [et.units(100).sub(ctx.stash.maxYield), '0.000000000001'], },

        // Confirming innocent bystander's balance not changed:

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], equals: [et.eth('30'), '0.000000000001'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet3.address], equals: [et.eth('18'), '0.000000000001'], },
    ],
})




.test({
    desc: "re-enter violator",
    actions: ctx => [
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              ctx.stash.maxRepay = r.maxRepay;
          },
        },
        // set the liquidator to be operator of the violator in order to be able act on violator's account and defer its liquidity check
        { from: ctx.wallet2, send: 'evc.setAccountOperator', args: [ctx.wallet2.address, ctx.wallet.address, NO_EXPIRY], },
        { action: 'sendBatch', batch: [
            { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet2.address], },
            { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },
          ],
          expectError: 'E_ViolatorLiquidityDeferred',
        },
    ],
})


.test({
    desc: "extreme collateral/borrow factors",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.99 },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(18), ctx.wallet2.address], },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.7', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;

                et.equals(ctx.stash.maxYield, '100', '.0000000001')
          },
        },

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 1<<16], }, //disable debt socialization

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // pool takes a loss

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: async r => {
            const liabilityValue = getRiskAdjustedValue(et.eth(18).sub(ctx.stash.maxRepay), 2.7, 1);

            et.equals(r.collateralValue, 0, '.00000001');
            et.equals(r.liabilityValue, liabilityValue, '0.01');
        }},

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxRepay, '.01'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '.0000000001'], },
    ],
})



.test({
    desc: "multiple collaterals",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(4), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { send: 'tokens.WETH.mint', args: [ctx.wallet2.address, et.eth(200)], },
        { from: ctx.wallet2, send: 'tokens.WETH.approve', args: [ctx.contracts.eVaults.eWETH.address, et.MaxUint256,], },
        { from: ctx.wallet2, send: 'eVaults.eWETH.deposit', args: [et.eth(1), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eWETH.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.39, 0.01);
        }, },

        // borrow increases in value

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '3.15', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eWETH.address],
          onResult: r => {
              ctx.stash.maxRepay = r.maxRepay;
              ctx.stash.maxYield = r.maxYield;
          },
        },
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.976, 0.01);
        }, },

        // liquidate TST, which is limited to amount owed

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eWETH.address, () => ctx.stash.maxRepay, 0], },

        // wasn't sufficient to fully restore health score

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: async r => {
            const liabilityValue = getRiskAdjustedValue(et.eth(4).sub(ctx.stash.maxRepay), 3.15, 1 / 0.4);

            const collateralValueTST2 = getRiskAdjustedValue(et.eth(100), .4, .75);
            const collateralValueWETH= getRiskAdjustedValue(et.eth(1).sub(ctx.stash.maxYield), .4, .75);
            et.equals(r.collateralValue / r.liabilityValue, collateralValueTST2.add(collateralValueWETH) / liabilityValue, 0.001);
        }},

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: () => [et.eth(100).add(ctx.stash.maxYield), '.0000000001'], },

        // violator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: () => [et.eth(4).sub(ctx.stash.maxRepay), '.1'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 100},
        { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet2.address], equals: [0, '.000000000001'], }, // FIXME: dust
    ],
})




.test({
    desc: "minimal collateral factor",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        // collateral factor set to minimum
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 1/10000 },

        // Can't exit market
        { from: ctx.wallet2, send: 'evc.disableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], expectError: 'E_AccountLiquidity' },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;
            },
        },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: () => ctx.stash.maxRepay, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, '0.00036364848258600745', '0.0000000001');
        }, },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            expectError: 'E_NoLiability',
        },
    ],
})



// wallet4 will be violator, using TST9 (6 decimals) as collateral

.test({
    desc: "non-18 decimal collateral",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST9.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        { action: 'setLTV', collateral: 'TST9', liability: 'TST', cf: 0.28 },

        { action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '17', },

        { send: 'tokens.TST9.mint', args: [ctx.wallet4.address, et.units(100, 6)], },
        { from: ctx.wallet4, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], },
        { from: ctx.wallet4, send: 'eVaults.eTST9.deposit', args: [et.units(10, 6), ctx.wallet4.address], },
        { from: ctx.wallet4, send: 'evc.enableCollateral', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST9.address], },

        { from: ctx.wallet4, send: 'evc.enableController', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(20), ctx.wallet4.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet4.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.08, 0.01);
        }, },

        { action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '15.5', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet4.address, ctx.contracts.eVaults.eTST9.address],
          onResult: r => {
            //   et.equals(r.maxRepay, et.eth('5.600403626769637232'), '0.0000000001');
            //   et.equals(r.maxYield, et.eth('0.806407532618212039'), '0.000000000001');

            ctx.stash.maxRepay = r.maxRepay;
            ctx.stash.maxYield = r.maxYield;
          },
        },
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet4.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.986, 0.001);
        }, },

        // Successful liquidation

        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: [0, '0.000000000001'], },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: et.eth('20'), },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST9.address, () => ctx.stash.maxRepay, 0], },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxYield, }, 

        // reserves:
        { call: 'eVaults.eTST.accumulatedFeesAssets', onResult: (r) => ctx.stash.reserves = r, },

        // violator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: () => [et.units(20).sub(ctx.stash.maxRepay).add(ctx.stash.reserves), '0.000000000001'], },
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet4.address], equals: () => et.units(10, 6).sub(ctx.stash.maxYield), },
    ],
})



.test({
    desc: "liquidation with high collateral exchange rate",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        { action: 'setLTV', collateral: 'TST', liability: 'TST2', cf: 0.95 },

        // Increase TST2 interest rate
        { send: 'tokens.TST.mint', args: [ctx.wallet4.address, et.eth(100)], },
        { from: ctx.wallet4, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], },
        { from: ctx.wallet4, send: 'eVaults.eTST.deposit', args: [et.eth(100), ctx.wallet4.address], },
        { from: ctx.wallet4, send: 'evc.enableCollateral', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet4, send: 'evc.enableController', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST2.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST2.borrow', args: [et.eth(50), ctx.wallet4.address], },

        { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmFixed', },
        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 10110*86400, },
        { send: 'eVaults.eTST2.touch', },
        { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '16', },

        // exchange rate is 5.879
        { call: 'eVaults.eTST2.convertToAssets', args: [et.eth(1)], equals: [5.879, '0.001'], },
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.881, 0.001);
            ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue)
        }, },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: async r => {
              ctx.stash.maxRepay = r.maxRepay;
              ctx.stash.maxYield = r.maxYield;

              const yieldAssets = await ctx.contracts.eVaults.eTST2.convertToAssets(r.maxYield);
              const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST2.address, ctx.contracts.tokens.WETH.address)
              const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST.address, ctx.contracts.tokens.WETH.address)
              et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
          },
        },
        async () => {
            const shares = await ctx.contracts.eVaults.eTST2.convertToShares(ctx.stash.maxYield);
            const yieldReverse = await ctx.contracts.eVaults.eTST2.convertToAssets(shares);

            // compounded rounding error
            et.expect(ctx.stash.maxYield.sub(yieldReverse)).to.equal(1);
        },

        { action: 'snapshot' },
        // Successful liquidation

        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: [0, '0.000000000001'] },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: et.eth('5'), },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], onResult: r => ctx.stash.balanceWithInterest = r, },

        // exchange rate rounding error doesn't influence liquidation 
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '0.000000000001'], },

        // reserves:
        { call: 'eVaults.eTST.accumulatedFeesAssets', onResult: (r) => ctx.stash.reserves = r, },

        // violator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => [ctx.stash.balanceWithInterest.sub(ctx.stash.maxYield), '0.000000000001'], },

        { action: 'revert' },

        // all collateral is liquidatable
        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '100', },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
        onResult: async r => {
            et.equals(r.maxYield, et.eth(100))
        },
      },
      { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, et.MaxUint256, 0], },
      { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 100, },
      { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },
    ],
})

.test({
    desc: "debt socialization",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.99 },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(18), ctx.wallet2.address], },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet3.address], },

        { call: 'eVaults.eTST.totalBorrows', equals: 19 },
        { action: 'snapshot', },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.7', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;

                et.equals(ctx.stash.maxYield, '100', '.0000000001') // all of the balance
          },
        },


        { call: 'evc.getCollaterals', args: [ctx.wallet2.address], onResult: r => et.equals(r.length, 1)}, 

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: async r => {
            et.equals(r.collateralValue, 0);
            et.equals(r.liabilityValue, 0);
        }},

        // 18 borrowed - repay is socialized. 1 + repay remains
        { call: 'eVaults.eTST.totalBorrows', equals: () => et.eth(1).add(ctx.stash.maxRepay) },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxRepay, '.01'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '.0000000001'], },

        { action: 'revert' },

        // no socialization with other collateral balance
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },
        // just 1 wei
        { from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [1, ctx.wallet2.address], },

        // liquidation continues as if the debt socialization was off - in the other test

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.7', },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;

                et.equals(ctx.stash.maxYield, '100', '.0000000001')
          },
        },

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 1<<16], }, //disable debt socialization

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // pool takes a loss

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: async r => {
            const liabilityValue = getRiskAdjustedValue(et.eth(18).sub(ctx.stash.maxRepay), 2.7, 1);

            et.equals(r.collateralValue, 0, '.00000001');
            et.equals(r.liabilityValue, liabilityValue, '0.01');
        }},

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxRepay, '.01'], },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.maxYield, '.0000000001'], },

        // TODO compare exchange rates

    ],
})

.test({
    desc: "collateral worth 0",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
        }, },

        { send: 'oracles.priceOracleCore.setPriceOverride', args: [ctx.contracts.eVaults.eTST2.address, 0], },


        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue, 0);
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              // no repay, yield full collateral balance
              et.equals(r.maxRepay, 0)
              et.equals(r.maxYield, 100)

              ctx.stash.maxYield = r.maxYield;
          },
        },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 1, 0], expectError: 'E_ExcessiveRepayAmount'},

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 5, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 100, },

        { action: 'snapshot'},

        // without debt socialization collateral is seized, but debt stays

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 1<<16], }, //disable debt socialization
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 5, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 100, },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 5, },

        // debt socialization switched on, no yield and no repay, but liquidation socializes debt

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                // no repay, no yield
                et.equals(r.maxRepay, 0)
                et.equals(r.maxYield, 0)
            },
        },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 100, },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 0, },
        
        { action: 'revert'},
        { action: 'snapshot'},

        // Try it once more, this time with debt socialization switched on all the time.
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },
        
        // Collateral is claimed, debt is socialized
        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 100, },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 0, },

        { action: 'revert'},

        // One wei of a second collateral (even worthless) will prevent socialization

        { from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [1, ctx.wallet2.address], },
        { send: 'oracles.priceOracleCore.setPriceOverride', args: [ctx.contracts.eVaults.eTST3.address, 0], },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 5, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 100, },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 5, },

        // second collateral can be liquidated to socialize debt

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address, 0, 0], },


        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet.address], equals: '100.000000000000000001', },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 0, },
    ],
})


.test({
    desc: "repay adjusted rounds down to 0",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        // reset deposit
        { from: ctx.wallet2, send: 'eVaults.eTST2.withdraw', args: [et.eth(100), ctx.wallet2.address, ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [40, ctx.wallet2.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [2, ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1, 0.01);
        }, },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '20', },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.1, 0.001);
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              // liability value = 40
              // collateral value (not RA) = 16
              // yield value initially = 40/0.8 = 50
              // repay value initially = 40
              // collateral value < yield, so: 
              //  repay value = 16 * 0.8 = 12
              //  yield value = 16
              // => repay = 12 * 2 / 40 = 0 (rounded down) 
              // yield = 16 * 40 / 16 = 40
              
              // no repay, yield full collateral balance
              et.equals(r.maxRepay, 0)
              et.equals(r.maxYield, '0.00000000000000004')

              ctx.stash.maxYield = r.maxYield;
          },
        },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0] },


        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: r => {
                // no repay, no yield
                et.equals(r.maxRepay, 0)
                et.equals(r.maxYield, 0)
            },
        },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 0, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: 0, },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: '0.00000000000000004', },

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: 0, },
    ],
})



.test({
    desc: "yield value converted to balance rounds down to 0. equivalent to pullDebt",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        // reset deposit
        { from: ctx.wallet2, send: 'eVaults.eTST2.withdraw', args: [et.eth(100), ctx.wallet2.address, ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [1, ctx.wallet2.address], },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '0.001', },
        { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '10', },

        // { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.95 },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [3000, ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1);
        }, },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '0.002', },


        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.5);
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              et.equals(r.maxYield, '0')
              et.equals(r.maxRepay, '0.000000000000003'); //3000
              ctx.stash.maxRepay = r.maxRepay;
          },
        },

        // min yield stops unprofitable liquidation
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 1], expectError: 'E_MinYield' },

        // liquidator doesn't have collateral to support debt taken on
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], expectError: 'E_AccountLiquidity' },

        // provide some collateral
        { send: 'eVaults.eTST2.deposit', args: [10, ctx.wallet.address], },
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },


        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        // violator's collateral unchanged
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: '0.000000000000000001', }, // 1

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: '0.000000000000003', },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: '0.00000000000000001', }, // 10

        // total borrows
        { call: 'eVaults.eTST.totalBorrows', equals: '0.000000000000003', },
    ],
})


.test({
    desc: "LTV ramping",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

    

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
            ctx.stash.origHS = r.collateralValue / r.liabilityValue;
        }, },

        { action: 'snapshot'},
        // ramp TST2 LTV down by half over 100 seconds
        { send: 'eVaults.eTST.setLTV', args: [ctx.contracts.eVaults.eTST2.address, 0.15e4, 100], },

        // account borrowing collateral value cut by half immediately
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS / 2, 0.01);
        }, },

        { action: 'snapshot'},
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [1, ctx.wallet2.address], expectError: 'E_AccountLiquidity', },
        { action: 'revert'},

        // but liquidation is not possible yet
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS, 0.01);
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              et.equals(r.maxRepay, 0);
              et.equals(r.maxYield, 0);
          },
        },

        // with time liquidation HS ramps down to target

        // 10% of ramp duration - liquidation HS > 1 still
        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 10, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.1 / 2), 0.01); // HS = 1.036
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              et.equals(r.maxRepay, 0);
              et.equals(r.maxYield, 0);
          },
        },

        // 15% - liquidation HS almost at 1
        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 5, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.15 / 2), 0.01); // HS = 1.009
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
          onResult: r => {
              et.equals(r.maxRepay, 0);
              et.equals(r.maxYield, 0);
          },
        },

        // 17% of ramp duration - liquidation now possible for a small discount

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 2, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.17 / 2), 0.01); // HS = 0.998
        }, },

        { action: 'snapshot'}, 

        // LTV is ramping down with every second. If we check liquidation now, during liquidation ltv will be different
        { call: 'eVaults.eTST.liquidationLTV', args: [ctx.contracts.eVaults.eTST2.address], equals: '2745',},
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, et.MaxUint256, 0], },
        { call: 'eVaults.eTST.liquidationLTV', args: [ctx.contracts.eVaults.eTST2.address], equals: '2730',},
        { action: 'revert'},

        // to get exact results, checkLiquidation should be made in the same block as the liquidation
        { action: 'snapshot'}, 
        { send: 'eVaults.eTST.touch', }, // mine a block

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.17 / 2), 0.01); // HS = 0.998
            ctx.stash.discount = 1 - r.collateralValue / r.liabilityValue;
        }, },

        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: async r => {
                et.equals(r.maxRepay, 5);
                et.equals(r.maxYield, 27.69, 0.01);
                const repayValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.eVaults.eTST.address, await ctx.contracts.eVaults.eTST.unitOfAccount())
                const yieldValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxYield, ctx.contracts.eVaults.eTST2.address, await ctx.contracts.eVaults.eTST.unitOfAccount())

                // discount checks out
                et.equals(repayValue / yieldValue , 1 - ctx.stash.discount, 0.000000001);

                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;
            },
        },
        // go back one block, stash should be accurate now
        { action: 'revert' },
        { action: 'snapshot' },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        // maxYield matches liquidation block exactly
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => et.eth(100).sub(ctx.stash.maxYield), },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxYield, }, 

        { action: 'revert' },





        // 50% of ramp duration - almost max discount

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 33, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.50 / 2), 0.01);
        }, },

        { action: 'snapshot'}, 
        { send: 'eVaults.eTST.touch', }, // mine a block

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.50 / 2), 0.01);
            ctx.stash.discount = 1 - r.collateralValue / r.liabilityValue;
            et.equals(ctx.stash.discount, 0.187, 0.001) // discount is 18.7%
        }, },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: async r => {
                et.equals(r.maxRepay, 5);
                et.equals(r.maxYield, 33.83, 0.01);
                const repayValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.eVaults.eTST.address, await ctx.contracts.eVaults.eTST.unitOfAccount())
                const yieldValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxYield, ctx.contracts.eVaults.eTST2.address, await ctx.contracts.eVaults.eTST.unitOfAccount())


                // discount checks out
                et.equals(repayValue / yieldValue, 1 - ctx.stash.discount, 0.000000001);

                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;
            },
        },
        // go back one block, stash should be accurate now
        { action: 'revert' },
        { action: 'snapshot' },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        // maxYield matches liquidation block exactly
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => et.eth(100).sub(ctx.stash.maxYield), },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxYield, }, 

        { action: 'revert' },



        // 70% of ramp duration - max discount

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 20, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.70 / 2), 0.01);
        }, },

        { action: 'snapshot'}, 
        { send: 'eVaults.eTST.touch', }, // mine a block

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS * (1 - 0.70 / 2), 0.01);

            // 1 - HS > 29%, discount maxes out at 20%
            et.equals(1 - r.collateralValue / r.liabilityValue, 0.296, 0.001);
            ctx.stash.discount = 0.2;
        }, },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: async r => {
                et.equals(r.maxRepay, 5);
                et.equals(r.maxYield, 34.37, 0.01);
                const repayValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.eVaults.eTST.address, await ctx.contracts.eVaults.eTST.unitOfAccount())
                const yieldValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxYield, ctx.contracts.eVaults.eTST2.address, await ctx.contracts.eVaults.eTST.unitOfAccount())

                // discount checks out
                et.equals(repayValue / yieldValue, 1 - ctx.stash.discount, 0.000000001);

                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;
            },
        },
        // go back one block, stash should be accurate now
        { action: 'revert' },
        { action: 'snapshot' },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        // maxYield matches liquidation block exactly
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => et.eth(100).sub(ctx.stash.maxYield), },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxYield, }, 

        { action: 'revert' },



        // 100% of ramp duration - max discount

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 30, },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS / 2, 0.01); 
        }, },

        { action: 'snapshot'}, 
        { send: 'eVaults.eTST.touch', }, // mine a block

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, true], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, ctx.stash.origHS / 2, 0.01);

            // 1 - HS > 45%, discount maxes out at 20%
            et.equals(1 - r.collateralValue / r.liabilityValue, 0.454, 0.001);
            ctx.stash.discount = 0.2;
        }, },
        { call: 'eVaults.eTST.checkLiquidation', args: [ctx.wallet.address, ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address],
            onResult: async r => {
                et.equals(r.maxRepay, 5);
                et.equals(r.maxYield, 34.37, 0.01);
                const repayValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.eVaults.eTST.address, await ctx.contracts.eVaults.eTST.unitOfAccount())
                const yieldValue = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxYield, ctx.contracts.eVaults.eTST2.address, await ctx.contracts.eVaults.eTST.unitOfAccount())

                // discount checks out
                et.equals(repayValue / yieldValue, 1 - ctx.stash.discount, 0.000000001);

                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;
            },
        },
        // go back one block, stash should be accurate now
        { action: 'revert' },
        { action: 'snapshot' },

        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        // violator
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: 0, },
        // maxYield matches liquidation block exactly
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: () => et.eth(100).sub(ctx.stash.maxYield), },

        // liquidator:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxRepay, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: () => ctx.stash.maxYield, }, 

        { action: 'revert' },
    ],
})


.run();

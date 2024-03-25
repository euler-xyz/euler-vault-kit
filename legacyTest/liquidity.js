const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


et.testSet({
    desc: "liquidity calculations",

    preActions: scenarios.basicLiquidity(),
})



.test({
    desc: "borrow isolation",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], expectError: 'E_ControllerDisabled', },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], expectError: 'EVC_ControllerViolation', },
    ],
})



.test({
    desc: "simple liquidity",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValues[0], 0);
            et.equals(r.collateralValues[1], 10 * 0.083 * .75 * .4, 0.0001);
            et.equals(r.liabilityValue, 0.1 * 2, 0.0001);
        }, },

        // No liquidation possible:
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'eVaults.eTST.liquidate', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address, 1, 0],
            expectError: 'E_ExcessiveRepayAmount'
        },

        // So 0.249 - 0.2 = 0.049 liquidity left
        // 0.049 = X * 2
        // X = .0245 (max TST that can be borrowed)

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(0.0246), ctx.wallet2.address], expectError: 'E_AccountLiquidity', },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(0.0244), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValues[0], 0);
            et.equals(r.collateralValues[1], 10 * 0.083 * .75 * .4, 0.0001);
            et.equals(r.liabilityValue, (.1 + 0.0244) * 2 , 0.0001);
        }, },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: [0.1244, 0.0001], },
    ],
})


.test({
    desc: "transfer eToken",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet2.address], equals: et.eth(10), },
        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth(10)], expectError: 'E_AccountLiquidity', },

        // From previous test, after borrowing 0.1 TST, liquidity left is 0.049
        // 0.049 = X * 0.083 * .75 * .4
        // Max TST2 available to transfer: 1.96787148594377510040
        // Note: In this test we are only depositor so can assume 1:1 eVault balance to underlying amount

        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth('1.969')], expectError: 'E_AccountLiquidity', },

        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth('1.967')], },


        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, 0.001);
            et.equals(r.collateralValues[1], 0.2, 0.001);
        }, },

        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth(0.002)], expectError: 'E_AccountLiquidity', },
    ],
})




.test({
    desc: "transfer dTokens",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, 0.0001);
        }, },


        // wallet3 deposits 6 TST2, giving collateralValue = 6 * 0.083 * .75 * .4 = 0.1494

        { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [et.eth(6), ctx.wallet3.address], },


        // The maximum amount of dTokens that can be transferred is:
        // 0.1494 = X * 2
        // X = .0747

        { from: ctx.wallet3, send: 'eVaults.eTST.pullDebt', args: [et.eth('.0748'), ctx.wallet2.address], expectError: 'E_ControllerDisabled', },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.pullDebt', args: [et.eth('.0748'), ctx.wallet2.address], expectError: 'E_AccountLiquidity', },

        { from: ctx.wallet3, send: 'eVaults.eTST.pullDebt', args: [et.eth('.0746'), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet3.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.1494, 0.01);
            et.equals(r.collateralValues[1], 6 * 0.083 * .75 * .4, 0.0001);
        }, },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2 - 0.1494, 0.01);
            et.equals(r.collateralValues[1], 10 * 0.083 * .75 * .4, 0.01);
        }, },
    ],
})




.test({
    desc: "transfer all debt",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, 0.0001);
        }, },


        // wallet3 deposits 10 TST2, same as wallet2

        { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [et.eth(10), ctx.wallet3.address], },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },

        // transfer full debt

        { from: ctx.wallet3, send: 'eVaults.eTST.pullDebt', args: [et.MaxUint256, ctx.wallet2.address], },


        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet3.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, 0.01);
            et.equals(r.collateralValues[1], 10 * 0.083 * .75 * .4, 0.0001);
        }, },
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'eVaults.eTST.accountLiquidityFull', args: [ctx.wallet2.address, false], expectError: "E_NoLiability", },
    ],
})



.test({
    desc: "exit market",
    actions: ctx => [
        { call: 'evc.getCollaterals', args: [ctx.wallet2.address], assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        // can exit collateral from liability market
        { from: ctx.wallet2, send: 'evc.disableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet2.address], assertEql: [ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet2, send: 'evc.disableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], expectError: 'E_AccountLiquidity', },

        { from: ctx.wallet2, send: 'tokens.TST.mint', args: [ctx.wallet2.address, et.eth(1)], },
        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet2.address], },

        { from: ctx.wallet2, send: 'evc.disableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'evc.getCollaterals', args: [ctx.wallet2.address], assertEql: [] },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(0);
        }, },
    ],
})


.run();

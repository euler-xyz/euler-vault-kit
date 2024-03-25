const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


et.testSet({
    desc: "borrow isolation",

    preActions: scenarios.basicLiquidity(),
})


.test({
    desc: "borrows are isolated",
    actions: ctx => [
        // First borrow is OK
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        // Can't enable another controller 
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], expectError: 'EVC_ControllerViolation' },

        // // Or borrow another asset
        // { from: ctx.wallet2, send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], expectError: 'E_ControllerDisabled', },
    ],
})


.test({
    desc: "multiple borrows are possible while in deferred liquidity",
    actions: ctx => [
        { action: 'setLTV', collateral: 'TST2', liability: 'TST3', cf: 0.3 },
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        // second borrow reverts
        { 
            action: 'sendBatch',
            from: ctx.wallet2,
            batch: [
                { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
            ],
            expectError: 'E_ControllerDisabled'
        },

        // unless it's repaid in the same batch
        { 
            action: 'sendBatch',
            from: ctx.wallet2,
            batch: [
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address] },
                { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST2.disableController', },
            ],
        },
        { call: 'eVaults.eTST2.debtOf', args: [ctx.wallet2.address], equals: 0 },

        // 3rd borrow

        // outstanding borrow
        { send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(100)], },
        { send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256], },
        { send: 'eVaults.eTST3.deposit', args: [et.eth(100), ctx.wallet.address], },
        { 
            action: 'sendBatch',
            from: ctx.wallet2,
            batch: [
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address] },
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address] },
                { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST3.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST2.disableController', },
            ],
            expectError: 'EVC_ControllerViolation',
        },

        // both repaid
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256], },
        { 
            action: 'sendBatch',
            from: ctx.wallet2,
            batch: [
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address] },
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address] },
                { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST3.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST2.disableController', },
                { send: 'eVaults.eTST3.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST3.disableController', },
            ],
        },

        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet2.address], equals: 0 },
        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet2.address], equals: 0 },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
        }, },

        // both repaid in reverse order
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256], },
        { 
            action: 'sendBatch',
            from: ctx.wallet2,
            batch: [
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address] },
                { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address] },
                { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST3.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
                { send: 'eVaults.eTST3.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST3.disableController', },
                { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet2.address], },
                { send: 'eVaults.eTST2.disableController', },
            ],
        },

        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet2.address], equals: 0 },
        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet2.address], equals: 0 },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
        }, },
    ],
})

// TODO
// .test({
//     desc: "getBorrowedMarket reverts with multiple borrows in deferred liquidity check",
//     actions: ctx => [
//         { action: 'setLTV', collateral: 'TST2', liability: 'TST2', cf: 0.3 },
//         { action: 'setLTV', collateral: 'TST2', liability: 'TST3', cf: 0.3 },

//         { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
//         { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

//         // second borrow reverts
//         { 
//             action: 'sendBatch',
//             from: ctx.wallet2,
//             batch: [
//                 { send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },
//                 { send: 'eVaults.eTST2.borrow', args: [et.eth('0.00000000001'), ctx.wallet2.address], },
//                 { call: 'exec.getAccountController', args: [ctx.wallet2.address], },
//             ],
//             expectError: 'E_TransientState'
//         },
//     ],
// })




.run();

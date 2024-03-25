const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


et.testSet({
    desc: "overrides",

    preActions: ctx => [
        ...scenarios.basicLiquidity()(ctx),
        { send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
        { send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(100)], },
        { send: 'eVaults.eTST3.deposit', args: [et.eth(10), ctx.wallet.address], },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2', },
        { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '0.5', },
        { action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '0.25', },
    ],
})

.test({
    desc: "override basic",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        // Account starts off normal, with single collateral and single borrow

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, .001); // 0.1 * 2
            et.equals(r.collateralValue, 1.5, .001); // 10 * 0.5 * 0.75 * 0.4
        }, },

        // Override is added for this liability/collateral pair

        { send: 'eVaults.eTST.setLTV', args: [
            ctx.contracts.eVaults.eTST2.address,
            Math.floor(0.97 * 1e4),
            0
        ], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, .001); // 0.1 * 2
            et.equals(r.collateralValue, 4.85, .001); // 10 * 0.5 * 0.97
        }, },
    ],
})



.test({
    desc: "override on non-collateral asset",
    actions: ctx => [
        // set collateral factor to 0
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0 },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], expectError: 'E_AccountLiquidity' },

        // Override is added for this liability/collateral pair

        { send: 'eVaults.eTST.setLTV', args: [
            ctx.contracts.eVaults.eTST2.address,
            Math.floor(0.97 * 1e4),
            0
        ], },

        // Borrow is possible now

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.liabilityValue, 0.2, .001); // 0.1 * 2
            et.equals(r.collateralValue, 4.85, .001); // 10 * 0.5 * 0.97
        }, },
    ],
})



.test({
    desc: "self-collateral not allowed",
    actions: ctx => [
        { send: 'eVaults.eTST2.setLTV', args: [
            ctx.contracts.eVaults.eTST2.address,
            Math.floor(0.8 * 1e4),
            0
        ], expectError: 'E_InvalidLTVAsset'},
    ],
})



// .test({
//     desc: "self-collateral override",
//     actions: ctx => [
//         // self-collateralization is not permitted by default
//         { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },
//         { from: ctx.wallet2, send: 'eVaults.eTST2.loop', args: [et.eth(10), ctx.wallet2.address], expectError: 'E_AccountLiquidity'},

//         // Override is added for the self collateralisation

//         { send: 'eVaults.eTST2.setLTV', args: [
//             ctx.contracts.eVaults.eTST2.address,
//             Math.floor(0.8 * 1e4),
//             0
//         ], },

//         // mint is now possible
//         { from: ctx.wallet2, send: 'eVaults.eTST2.loop', args: [et.eth(10), ctx.wallet2.address], },

//         { call: 'eVaults.eTST2.accountLiquidity', args: [ctx.wallet2.address], onResult: r => {
//             et.equals(r.liabilityValue, 5, .001); // 10 * 0.5 (price) / 1 (BF)
//             et.equals(r.collateralValue, 8, .001); // 20 * 0.5 (price) * 0.8 (CF)
//         }, },

//         // set override to 0
//         { send: 'eVaults.eTST2.setLTV', args: [
//             ctx.contracts.eVaults.eTST2.address,
//             0,
//             0,
//         ], },

//         // account is violation now
//         { call: 'eVaults.eTST2.accountLiquidity', args: [ctx.wallet2.address], onResult: r => {
//             et.equals(r.collateralValue, 0);
//             et.equals(r.liabilityValue, 5, .001); // 10 * 0.5 (price) / 1 (BF)
//         }, },
//     ],
// })


// TODO
// .test({
//     desc: "override getters",
//     actions: ctx => [
//         { call: 'eVaults.eTST.getOverride', args: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address,], onResult: r => {
//             et.expect(r.enabled).to.equal(false);
//             et.expect(r.collateralFactor).to.equal(0);
//         }},
//         { call: 'eVaults.eTST.getOverrideCollaterals', args: [ctx.contracts.eVaults.eTST.address], onResult: r => {
//             et.expect(r.length).to.equal(0);
//         }},
//         { call: 'eVaults.eTST.getOverrideLiabilities', args: [ctx.contracts.eVaults.eTST2.address], onResult: r => {
//             et.expect(r.length).to.equal(0);
//         }},

//         { send: 'eVaults.eTST.setLTV', args: [
//             ctx.contracts.eVaults.eTST.address,
//             ctx.contracts.eVaults.eTST2.address,
//             {
//                 enabled: true,
//                 collateralFactor: Math.floor(0.97 * 1e4),
//             },
//         ], },

//         { call: 'eVaults.eTST.getOverride', args: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address,], onResult: r => {
//             et.expect(r.enabled).to.equal(true);
//             et.expect(r.collateralFactor).to.equal(0.97 * 1e4);
//         }},
//         { call: 'eVaults.eTST.getOverrideCollaterals', args: [ctx.contracts.eVaults.eTST.address], onResult: r => {
//             et.expect(r.length).to.equal(1);
//             et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST2.address);
//         }},
//         { call: 'eVaults.eTST.getOverrideLiabilities', args: [ctx.contracts.eVaults.eTST2.address], onResult: r => {
//             et.expect(r.length).to.equal(1);
//             et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
//         }},

//         // no duplicates

//         { send: 'eVaults.eTST.setLTV', args: [
//             ctx.contracts.eVaults.eTST.address,
//             ctx.contracts.eVaults.eTST2.address,
//             {
//                 enabled: true,
//                 collateralFactor: Math.floor(0.5 * 1e4),
//             },
//         ], },

//         { call: 'eVaults.eTST.getOverride', args: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address,], onResult: r => {
//             et.expect(r.enabled).to.equal(true);
//             et.expect(r.collateralFactor).to.equal(0.5 * 1e4);
//         }},
//         { call: 'eVaults.eTST.getOverrideCollaterals', args: [ctx.contracts.eVaults.eTST.address], onResult: r => {
//             et.expect(r.length).to.equal(1);
//             et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST2.address);
//         }},
//         { call: 'eVaults.eTST.getOverrideLiabilities', args: [ctx.contracts.eVaults.eTST2.address], onResult: r => {
//             et.expect(r.length).to.equal(1);
//             et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
//         }},

//         // disabling removes from array

//         // add one more override for TST as liability
//         { send: 'eVaults.eTST.setLTV', args: [
//             ctx.contracts.eVaults.eTST.address,
//             ctx.contracts.eVaults.eTST3.address,
//             {
//                 enabled: true,
//                 collateralFactor: Math.floor(0.6 * 1e4),
//             },
//         ], },
//         { send: 'eVaults.eTST.setLTV', args: [
//             ctx.contracts.eVaults.eTST.address,
//             ctx.contracts.eVaults.eTST2.address,
//             {
//                 enabled: false,
//                 collateralFactor: Math.floor(0.6 * 1e4),
//             },
//         ], },

//         { call: 'eVaults.eTST.getOverride', args: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address,], onResult: r => {
//             et.expect(r.enabled).to.equal(false);
//             et.expect(r.collateralFactor).to.equal(0.6 * 1e4);
//         }},
//         { call: 'eVaults.eTST.getOverrideCollaterals', args: [ctx.contracts.eVaults.eTST.address], onResult: r => {
//             et.expect(r.length).to.equal(1);
//             et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST3.address);
//         }},
//         { call: 'eVaults.eTST.getOverrideLiabilities', args: [ctx.contracts.eVaults.eTST2.address], onResult: r => {
//             et.expect(r.length).to.equal(0);
//         }},
//     ],
// })



.run();

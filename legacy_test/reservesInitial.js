const et = require('./lib/eTestLib');

et.testSet({
    desc: "reserves initial value",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.units(100)], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });

            actions.push({ from, send: 'tokens.TST9.mint', args: [from.address, et.units(100, 6)], });
            actions.push({ from, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], });

            actions.push({ from, send: 'tokens.TST10.mint', args: [from.address, et.units(100, 0)], });
            actions.push({ from, send: 'tokens.TST10.approve', args: [ctx.contracts.eVaults.eTST10.address, et.MaxUint256,], });
        }

        return actions;
    },
})



// .test({
//     desc: "exchange rate manipulation, 18 decimal place token",

//     actions: ctx => [
//         { call: 'eVaults.eTST.totalSupply' },

//         // Deposit exactly 1 wei
//         { send: 'eVaults.eTST.deposit', args: [1, ctx.wallet.address], },

//         { send: 'tokens.TST.transfer', args: [ctx.contracts.eVaults.eTST.address, et.units(50)], },

//         { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.units(10), ctx.wallet2.address], },

//         { send: 'eVaults.eTST.withdraw', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
//         { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.MaxUint256, ctx.wallet2.address, ctx.wallet2.address], },

//         // Without initial reserves, user is able to steal the 10 unit deposit:
//         // { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: [110, .0001], },
//         // { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], equals: [90, .0001], },

//         // With initial reserves, the 50 units were mostly donated to the reserves:
//         { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: [50, .0001], },
//         { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], equals: [100, .0001], },
//         { call: 'eVaults.eTST.accumulatedFeesAssets', equals: [50, .0001], },
//     ],
// })



// .test({
//     desc: "exchange rate manipulation, non-18 decimal place token",
//     actions: ctx => [
//         { call: 'eVaults.eTST9.totalSupply', equals: 0},
//         { call: 'eVaults.eTST9.totalAssets', equals: 0}, // initial reserve is not scaled up

//         // Deposit exactly 1 wei (base unit)
//         { send: 'eVaults.eTST9.deposit', args: [1, ctx.wallet.address], },

//         { send: 'tokens.TST9.transfer', args: [ctx.contracts.eVaults.eTST9.address, et.units(50, 6)], },

//         { from: ctx.wallet2, send: 'eVaults.eTST9.deposit', args: [9, ctx.wallet2.address], },


//         { send: 'eVaults.eTST9.withdraw', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
//         { from: ctx.wallet2, send: 'eVaults.eTST9.withdraw', args: [et.MaxUint256, ctx.wallet2.address, ctx.wallet2.address], },


//         // With non-18 decimal tokens, the initial reserves are much lower value, and 1 wei deposit 
//         // is scaled up. The effect is negligible
//         { call: 'tokens.TST9.balanceOf', args: [ctx.wallet.address], equals: et.units(99.99995, 6), },
//         { call: 'tokens.TST9.balanceOf', args: [ctx.wallet2.address], equals: et.units(100, 6), },
//         { call: 'eVaults.eTST9.accumulatedFeesAssets', equals: et.units(0.00005, 6), },
//     ],
// })



// .test({
//     desc: "exchange rate manipulation, 0 decimal place token",
//     actions: ctx => [
//         { call: 'eVaults.eTST10.totalSupply', equals: 0},
//         { call: 'eVaults.eTST10.totalAssets', equals: 0}, // initial reserve is not scaled up

//         // Deposit exactly 1 wei
//         { send: 'eVaults.eTST10.deposit', args: [1, ctx.wallet.address], },

//         { send: 'tokens.TST10.transfer', args: [ctx.contracts.eVaults.eTST10.address, 50], },

//         { from: ctx.wallet2, send: 'eVaults.eTST10.deposit', args: [10, ctx.wallet2.address], },


//         { send: 'eVaults.eTST10.withdraw', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
//         { from: ctx.wallet2, send: 'eVaults.eTST10.withdraw', args: [et.MaxUint256, ctx.wallet2.address, ctx.wallet2.address], },

//         // With 0 decimal tokens, effect is small
//         { call: 'tokens.TST10.balanceOf', args: [ctx.wallet.address], equals: et.BN(99), },
//         { call: 'tokens.TST10.balanceOf', args: [ctx.wallet2.address], equals: et.BN(100), },
//         { call: 'eVaults.eTST10.accumulatedFeesAssets', equals: et.BN(1), },
//     ],
// })




.test({
    desc: "no first depositor donation, 18 decimal place token",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [et.units(1, 18), ctx.wallet.address], },
        { send: 'eVaults.eTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        // can withdraw full deposit
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.units(100, 18), },
        { call: 'eVaults.eTST.accumulatedFeesAssets', equals: 0 },
    ],
})



.test({
    desc: "no first depositor donation, non-18 decimal place token",
    actions: ctx => [
        { send: 'eVaults.eTST9.deposit', args: [et.units(1, 6), ctx.wallet.address], },
        { send: 'eVaults.eTST9.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        // can withdraw full deposit
        { call: 'tokens.TST9.balanceOf', args: [ctx.wallet.address], equals: et.units(100, 6), },
        { call: 'eVaults.eTST9.accumulatedFeesAssets', equals: 0 },
    ],
})



.test({
    desc: "no first depositor donation, 0 decimal place token",
    actions: ctx => [
        { send: 'eVaults.eTST10.deposit', args: [2, ctx.wallet.address], },
        { send: 'eVaults.eTST10.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        // one token is donated to the reserves
        { call: 'tokens.TST10.balanceOf', args: [ctx.wallet.address], equals: et.BN(100), },
        { call: 'eVaults.eTST10.accumulatedFeesAssets', equals: 0 },
    ],
})




.test({
    desc: "market activation with pre-existing pool balance",
    actions: ctx => [
        { send: 'tokens.TST.mint', args: [ctx.contracts.eVaults.eTST.address, et.eth(10)] },

        // internal balance tracking ignores existing deposit
        { call: 'eVaults.eTST.accumulatedFeesAssets', equals: 0 },
        { call: 'eVaults.eTST.totalSupply', equals: 0 },
        { call: 'eVaults.eTST.totalAssets', equals: 0 },

        // { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100)], },

        // // First depositor must deposit more than existing balance
        // { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], expectError: 'E_ZeroShares'},
        // { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], expectError: 'E_ZeroShares'},

        // { send: 'eVaults.eTST.deposit', args: [et.eth(10).add(1), ctx.wallet.address], },

        // // 1 wei share is created
        // { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: et.BN(1), },
        // { send: 'eVaults.eTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        // { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(100), },

        // { call: 'eVaults.eTST.accumulatedFeesAssets', equals: 0 },
        // { call: 'eVaults.eTST.totalSupply', equals: 0 },
        // { call: 'eVaults.eTST.totalAssets', equals: et.eth(10) },
        // { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], equals: et.eth(10), },
    ],
})


.run();

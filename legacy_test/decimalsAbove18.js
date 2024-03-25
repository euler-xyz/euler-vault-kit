const et = require('./lib/eTestLib');

et.testSet({
    desc: "tokens with above 18 decimals",
})


.test({
    desc: "names, symbols and decimals",
    actions: ctx => [
        { call: 'tokens.UTST.name', args: [], assertEql: 'Unactivated Test Token', },
        { call: 'tokens.UTST.symbol', args: [], assertEql: 'UTST', },
        { call: 'tokens.UTST.decimals', args: [], equals: [18], },

        { from: ctx.wallet, send: 'tokens.UTST.changeDecimals', args: [19], },
        { call: 'tokens.UTST.decimals', args: [], equals: [19], },
    ],
})


.test({
    desc: "initial supplies and balances",
    actions: ctx => [
        { from: ctx.wallet, send: 'tokens.UTST.changeDecimals', args: [19], },
        
        { call: 'tokens.UTST.totalSupply', args: [], assertEql: et.units('0', 19), },
        { call: 'tokens.UTST.balanceOf', args: [ctx.wallet.address], assertEql: et.units('0', 19) },

        { from: ctx.wallet, send: 'tokens.UTST.mint', args: [ctx.wallet2.address, et.units('100', 19)] },

        { call: 'tokens.UTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.units('100', 19) },
    ],
})

// TODO
// .test({
//     desc: "activate market and setup default eVault",
//     actions: ctx => [
//         { from: ctx.wallet, send: 'tokens.UTST.changeDecimals', args: [19], },

//         { from: ctx.wallet, send: 'genericFactory.activate', args: [true, ctx.contracts.tokens.UTST.address, ctx.contracts.riskManagers.riskManagerCore.address, []], expectError: 'E_TooManyDecimals', },

//         {call: 'riskManagers.riskManagerCore.getMarketByUnderlying', args: [ctx.contracts.tokens.UTST.address], assertEql: et.AddressZero },
//     ],
// })


.run();
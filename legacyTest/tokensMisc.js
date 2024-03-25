const et = require('./lib/eTestLib');

et.testSet({
    desc: "tokens misc",
})


.test({
    desc: "names and symbols",
    actions: ctx => [
        { call: 'eVaults.eTST.name', args: [], assertEql: 'Unnamed Euler Vault', },
        { call: 'eVaults.eTST.symbol', args: [], assertEql: 'UNKNOWN', },
        { call: 'dTokens.dTST.name', args: [], assertEql: 'Debt token of Unnamed Euler Vault', },
        { call: 'dTokens.dTST.symbol', args: [], assertEql: 'dUNKNOWN', },
    ],
})


.test({
    desc: "underlying asset",
    actions: ctx => [
        { call: 'eVaults.eTST.asset', args: [], assertEql: ctx.contracts.tokens.TST.address, },
    ],
})


.test({
    desc: "initial supplies and balances",
    actions: ctx => [
        // Total supply is the default reserves = 1e6 wei or et.eth('0.000000000001')
        { call: 'eVaults.eTST.totalSupply', args: [], assertEql: 0, },
        { call: 'eVaults.eTST.totalAssets', args: [], assertEql: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], assertEql: et.eth(0), },

        { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.totalBorrowsExact', args: [], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet.address], assertEql: et.eth(0), },
    ],
})



.run();

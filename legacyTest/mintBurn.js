const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


et.testSet({
    desc: "minting and burning",

    preActions: scenarios.basicLiquidity(),
})



.test({
    desc: "no liquidity",
    actions: ctx => [
        { from: ctx.wallet4, send: 'evc.enableController', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST.loop', args: [et.eth(1), ctx.wallet4.address], expectError: 'E_AccountLiquidity', },
    ],
})


.test({
    desc: "borrow on empty pool, and repay",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', },

        { call: 'eVaults.eTST3.totalSupply', equal: et.formatUnits(et.DefaultReserve), },
        { call: 'eVaults.eTST3.totalBorrows', assertEql: 0, },

        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'eVaults.eTST3.loop', args: [et.eth(1), ctx.wallet.address], },

        { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], assertEql: et.eth(1), },

        { send: 'eVaults.eTST3.deloop', args: [et.eth(1), ctx.wallet.address], },

        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], equals: 0, },

        { send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
        { send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(1)], },
        { send: 'eVaults.eTST3.deposit', args: [et.eth(1), ctx.wallet.address], },

        { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'eVaults.eTST3.totalSupply', assertEql: et.eth(1), },
        { call: 'eVaults.eTST3.totalBorrows', assertEql: 0, },
    ],
})



.run();

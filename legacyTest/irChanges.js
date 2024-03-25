const et = require('./lib/eTestLib');

et.testSet({
    desc: "changing interest rates",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
        }

        for (let from of [ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
        }

        actions.push({ from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(0.5), ctx.wallet.address], });
        actions.push({ from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(0.5), ctx.wallet.address], });

        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },);

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.01', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.05', });

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.21});

        actions.push({ from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },);

        actions.push({ action: 'jumpTime', time: 31*60, });

        return actions;
    },
})



.test({
    desc: "IRMLinear",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmLinear', },

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.units('0.0', 27), },

        // Mint some extra so we can pay interest
        { send: 'tokens.TST.mint', args: [ctx.wallet2.address, et.eth(0.1)], },

        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(1), },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.5), ctx.wallet2.address], },
        { action: 'checkpointTime', },

        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(0.5), },

        // 50% of pool loaned out
        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.5', '0.5'), },

        // 1 block later

        { action: 'jumpTimeAndMine', time: 1, },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth('0.500000000792218463'), },

        // Interest rate unchanged, because no operations called that would update it

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.5', '0.5'), },

        // Borrow a little more

        { action: 'jumpTime', time: 1, },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.2), ctx.wallet2.address], },

        // New loan plus 2 blocks worth of interest at previous IR

        // borrows round up
        { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth('0.700000001584436927'), },

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.700000001584436926', '0.3'), },

        // 1 block later

        { action: 'jumpTimeAndMine', time: 1, },

        { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth('0.700000003137185118'), },

        // IR unchanged

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.700000001584436926', '0.3'), },

        // Re-pay some:

        { action: 'jumpTime', time: 1, },
        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.eth('0.4'), ctx.wallet2.address], },

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.300000004693049228', '0.7'), },

        // Now wallet deposits a bit more

        { action: 'jumpTime', time: 1, },
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(.6), ctx.wallet.address], },

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.300000004978437363', '1.3'), },

        // Now wallet withdraws some

        { action: 'jumpTime', time: 1, },
        { from: ctx.wallet, send: 'eVaults.eTST.withdraw', args: [et.eth(.2), ctx.wallet.address, ctx.wallet.address], },

        { call: 'eVaults.eTST.interestRate', args: [], assertEql: et.linearIRM('0.300000005156804948', '1.1'), },
    ],
})



.run();

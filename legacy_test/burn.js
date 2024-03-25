const et = require('./lib/eTestLib');

et.testSet({
    desc: "burn",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
        }

        for (let from of [ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
        }

        actions.push({ from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], });

        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },);

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.01', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.05', });

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.21})

        actions.push({ action: 'jumpTime', time: 31*60, });

        return actions;
    },
})


.test({
    desc: "burn with max_uint256 repays the debt in full or up to the available underlying balance",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'evc.getCollaterals', args: [ctx.wallet2.address],
            assertEql: [ctx.contracts.eVaults.eTST2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },

        // Two separate borrows, .4 and .1:
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.4), ctx.wallet2.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.dTokens.dTST.address);
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(et.AddressZero);
            et.expect(logs[0].args.to).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.value).to.equal(et.eth(.4));
        }},
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet2.address], },
        { action: 'checkpointTime', },

        // Make sure the borrow market is recorded
        { call: 'evc.getCollaterals', args: [ctx.wallet2.address],
            assertEql: [ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
        }, },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100.5), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        // Wait 1 day

        { action: 'jumpTime', time: 86400, },
        { action: 'mineEmptyBlock', },

        // No interest was charged
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        // nothing to burn
        { from: ctx.wallet2, send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100.5), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        // eVault balance is less than debt
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(0.1), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100.4), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equal: [et.eth(0.4), '.000000000000000001'], },

        // eVault balance is greater than debt
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(99.4), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], equal: [et.eth(0.6), '.1'], },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], equal: [et.eth(0.5), '000000000000000001'], },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
    ],
})


.test({
    desc: "burn when owed amount is 0 is a no-op",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'evc.getCollaterals', args: [ctx.wallet2.address],
            assertEql: [ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(99), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(99), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
    ],
})


.test({
    desc: "burn for 0 is a no-op",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'evc.getCollaterals', args: [ctx.wallet2.address],
            assertEql: [ctx.contracts.eVaults.eTST2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.5), ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100.5), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        // burning 0 is a no-op 
        { from: ctx.wallet2, send: 'eVaults.eTST.deloop', args: [0, ctx.wallet2.address], }, 
    ],
})


.run();
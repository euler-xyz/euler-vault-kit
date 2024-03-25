const et = require('./lib/eTestLib');

const debtExact = val => val.mul(et.BN(2).pow(31)).div(et.BN(10).pow(9))

et.testSet({
    desc: "borrow basic",

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

        actions.push({ action: 'jumpTime', time: 31*60, });

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.21 });

        return actions;
    },
})


.test({
    desc: "basic borrow and repay, with no interest",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'evc.getCollaterals', args: [ctx.wallet2.address],
          assertEql: [ctx.contracts.eVaults.eTST2.address], },

        // Repay when max nothing owed is a no-op
        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet2.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.eth(100), ctx.wallet2.address], expectError: 'E_RepayTooMuch'},


        // Liability vault must be the EVC controller
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.4), ctx.wallet2.address], expectError: 'E_ControllerDisabled' },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },

        // Two separate borrows, .4 and .1:
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.4), et.getSubAccount(ctx.wallet2.address, 1)], expectError: 'E_BadAssetReceiver', },

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

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.eth(0.5), ctx.wallet2.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.dTokens.dTST.address);
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.to).to.equal(et.AddressZero);
            et.expect(logs[0].args.value).to.equal(et.eth(.5));
        }},

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(100), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], assertEql: et.eth(0), },

        { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.totalBorrowsExact', args: [], assertEql: et.eth(0), },

        // controller is released
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(0);
        }, },
    ],
})



.test({
    desc: "basic borrow and repay, very small interest",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units(1, 27), },

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units(1, 27), },

        // Mint some extra so we can pay interest
        { send: 'tokens.TST.mint', args: [ctx.wallet2.address, et.eth(0.1)], },
        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units('1.000000003170979198376458650', 27), },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.5), ctx.wallet2.address], },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units('1.000000006341958406808026377', 27), }, // 1 second later, so previous accumulator squared

        // 1 block later, notice amount owed is rounded up:

        { action: 'mineEmptyBlock', },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address],        assertEql: et.eth('0.500000001585489600'), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: [debtExact(et.units('0.500000001585489599188229324', 27)), '0.00000000000000001'], },
        // Try to pay off full amount:

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.eth('0.500000001585489600'), ctx.wallet2.address], },

        // Tiny bit more accrued in previous block:

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address],        assertEql: et.eth('0.000000001585489604'), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: [debtExact(et.units('0.000000001585489604000000000', 27)), '0.00000000000000001'], },

        // Use max uint to actually pay off full amount:

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], assertEql: et.eth(0), },

        { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.totalBorrowsExact', args: [], assertEql: et.eth(0), },
        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(0);
        }, },
    ],
})



.test({
    desc: "fractional debt amount",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units(1, 27), },

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units(1, 27), },

        // Mint some extra so we can pay interest
        { send: 'tokens.TST.mint', args: [ctx.wallet2.address, et.eth(0.1)], },
        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units('1.000000003170979198376458650', 27), },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.5), ctx.wallet2.address], },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0.5), },

        { call: 'eVaults.eTST.interestAccumulator', args: [], assertEql: et.units('1.000000006341958406808026377', 27), }, // 1 second later, so previous accumulator squared

        // Turn off interest, but 1 block later so amount owed is rounded up:

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth('0.500000001585489600'), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: [debtExact(et.units('0.500000001585489599188229324', 27)), '0.00000000000000001'], },

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [et.eth('0.500000001585489599'), ctx.wallet2.address], },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: et.units('1', 0), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: et.BN(2).pow(31), },

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: et.units('2', 0), },
        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: [debtExact(et.units('1.000000003', 9)), '0.00000000000000001'], },

        { from: ctx.wallet2, send: 'eVaults.eTST.repay', args: [2, ctx.wallet2.address], },

        { call: 'eVaults.eTST.debtOfExact', args: [ctx.wallet2.address], equals: 0, },

        { from: ctx.wallet2, send: 'eVaults.eTST.disableController', },
        { call: 'evc.getControllers', args: [ctx.wallet2.address], onResult: r => {
            et.expect(r.length).to.equal(0);
        }, },
    ],
})


.test({
    desc: "amounts at the limit",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        // Try to borrow more tokens than exist in the pool:
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(100000), ctx.wallet2.address], expectError: 'E_InsufficientCash', },

        // Max uint specifies all the tokens in the pool, which is 1 TST:

        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], equals: et.eth(1), },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], equals: et.eth(100), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: et.eth(0), },

        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], equals: et.eth(0), },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], equals: et.eth(101), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], equals: et.eth(1), },
    ],
})


.test({
    desc: "owed amount is convertible to assets",
    actions: ctx => [
        { call: "eVaults.eTST.test_maxOwedAndAssetsConversions" },
    ],
})



.run();

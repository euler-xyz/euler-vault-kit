const et = require('./lib/eTestLib');

et.testSet({
    desc: "transfer dTokens",

    preActions: ctx => {
        let actions = [
            { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },
            { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmZero', },
        ];

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST9.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST3.mint', args: [from.address, et.eth(1000)], });
        }

        for (let from of [ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST9.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST3.mint', args: [from.address, et.eth(100)], });
        }

        actions.push({ from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], });
        actions.push({ from: ctx.wallet, send: 'eVaults.eTST3.deposit', args: [et.eth(1000), ctx.wallet.address], });
        actions.push({ from: ctx.wallet, send: 'eVaults.eTST9.deposit', args: [et.eth(1), ctx.wallet.address], });
        actions.push({ from: ctx.wallet, send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },);
        actions.push({ from: ctx.wallet, send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },);
        
        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST9.deposit', args: [et.eth(1), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [et.eth(1), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },);
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST9.address], },);
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },);

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.01', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.05', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '.00001', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '.00001', });

        actions.push({ action: 'jumpTime', time: 31*60, });

        // actions.push({ action: 'setLTV', collateral: 'TST', liability: 'TST', cf: 0.95 });
        actions.push({ action: 'setLTV', collateral: 'TST3', liability: 'TST9', cf: 0.95 });
        actions.push({ action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 });
        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 },);
        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST9', cf: 0.3 },);

        return actions;
    },
})


.test({
    desc: "basic transfers to self",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.25), ctx.wallet2.address], },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: et.eth(0), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(.25), },

        // can't just transfer to somebody else
        // { from: ctx.wallet2, send: 'dTokens.dTST.transfer', args: [ctx.wallet.address, et.eth(.1)], expectError: 'E_UnauthorizedDebtTransfer', },

        { from: ctx.wallet, send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        // { from: ctx.wallet2, send: 'dTokens.dTST.transfer', args: [ctx.wallet.address, et.eth(.1)], expectError: 'E_UnauthorizedDebtTransfer', },

        // can't pullDebt to self
        { from: ctx.wallet2, send: 'eVaults.eTST.pullDebt', args: [et.eth(.1), ctx.wallet2.address], expectError: 'E_SelfTransfer', },

        // but you can always transferFrom to yourself from someone else (assuming you have enough collateral)
        { from: ctx.wallet, send: 'eVaults.eTST.pullDebt', args: [et.eth(.1), ctx.wallet2.address], onLogs: allLogs => {
            {
                let logs = allLogs.filter(l => l.address === ctx.contracts.dTokens.dTST.address);
                et.expect(logs.length).to.equal(2);

                et.expect(logs[0].name).to.equal('Transfer');
                et.expect(logs[0].args.from).to.equal(ctx.wallet2.address);
                et.expect(logs[0].args.to).to.equal(et.AddressZero);
                et.expect(logs[0].args.value).to.equal(et.eth(.1));

                et.expect(logs[1].name).to.equal('Transfer');
                et.expect(logs[1].args.from).to.equal(et.AddressZero);
                et.expect(logs[1].args.to).to.equal(ctx.wallet.address);
                et.expect(logs[1].args.value).to.equal(et.eth(.1));
            }

            {
                let logs = allLogs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
                et.expect(logs.length).to.equal(3);
                et.expect(logs[0].name).to.equal('Repay');
                et.expect(logs[1].name).to.equal('Borrow');
                et.expect(logs[2].name).to.equal('VaultStatus');
            }
        }},

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: et.eth(.1), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(.15), },

        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST3.address], },

        // Add some interest-dust, and then do a max transfer

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
        { action: 'jumpTimeAndMine', time: 1800, },

        { from: ctx.wallet, send: 'eVaults.eTST.pullDebt', args: [et.MaxUint256, ctx.wallet2.address], },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], equals: ['0.2500014', '0.0000001'], },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
    ],
})


.test({
    desc: "lower decimals, partial transfer",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmFixed', },

        { send: 'tokens.TST9.mint', args: [ctx.wallet.address, et.units(10000, 6)], },
        { send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], },
        { send: 'eVaults.eTST9.deposit', args: [et.MaxUint256, ctx.wallet.address], },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST9.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [et.getSubAccount(ctx.wallet2.address, 1), ctx.contracts.eVaults.eTST9.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST9.borrow', args: [et.units(8000, 6), ctx.wallet2.address], },
        { action: 'checkpointTime', },

        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.MaxUint256, ctx.wallet2.address], },
        ], expectError: 'E_AccountLiquidity', },

        { from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [et.getSubAccount(ctx.wallet2.address, 1), et.eth(50)], },
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [et.getSubAccount(ctx.wallet2.address, 1), ctx.contracts.eVaults.eTST2.address], },

        { action: 'jumpTime', time: 60, },
        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.units(1000, 6), ctx.wallet2.address], },
        ], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.dTokens.dTST9.address);

            et.expect(logs.length).to.equal(2);

            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.to).to.equal(et.AddressZero);
            et.expect(logs[0].args.value).to.equal(et.units('999.998477', 6));

            et.expect(logs[1].name).to.equal('Transfer');
            et.expect(logs[1].args.from).to.equal(et.AddressZero);
            et.expect(logs[1].args.to.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet2.address, 1).toLowerCase());
            et.expect(logs[1].args.value).to.equal(et.units('1000', 6));
        }, },

        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet2.address], equals: et.units('7000.001523', 6), },
        { call: 'eVaults.eTST9.debtOf', args: [et.getSubAccount(ctx.wallet2.address, 1)], equals: [et.units(1000, 6)], },

        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.units(7000.01, 6), ctx.wallet2.address], },
        ], expectError: 'E_InsufficientBalance', },

        { action: 'jumpTime', time: 10, },
        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.units(7000, 6), ctx.wallet2.address], },
        ], },
        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet2.address], equals: [et.units('0.001745', 6)], },
    ],
})


.test({
    desc: "lower decimals, full transfer",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmFixed', },

        { send: 'tokens.TST9.mint', args: [ctx.wallet.address, et.units(10000, 6)], },
        { send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], },
        { send: 'eVaults.eTST9.deposit', args: [et.MaxUint256, ctx.wallet.address], },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST9.address], },
        { from: ctx.wallet2, send: 'evc.enableController', args: [et.getSubAccount(ctx.wallet2.address, 1), ctx.contracts.eVaults.eTST9.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST9.borrow', args: [et.units(8000, 6), ctx.wallet2.address], },
        { action: 'checkpointTime', },

        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.MaxUint256, ctx.wallet2.address], },
        ], expectError: 'E_AccountLiquidity',},

        { from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [et.getSubAccount(ctx.wallet2.address, 1), et.eth(50)], },
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [et.getSubAccount(ctx.wallet2.address, 1), ctx.contracts.eVaults.eTST2.address], },

        { action: 'jumpTime', time: 60, },
        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet2.address, 1), send: 'eVaults.eTST9.pullDebt', args: [et.MaxUint256, ctx.wallet2.address], },
        ], },

        { call: 'eVaults.eTST9.debtOfExact', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST9.debtOf', args: [et.getSubAccount(ctx.wallet2.address, 1)], equals: [et.units('8000.001523', 6)], },
    ],
})



.run();

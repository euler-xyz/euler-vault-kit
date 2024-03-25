const et = require('./lib/eTestLib');

et.testSet({
    desc: "deposit/withdraw balances, no interest",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(10)], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        }

        return actions;
    },
})


.test({
    desc: "basic deposit/withdraw",
    actions: ctx => [
        { send: 'eVaults.eTST.withdraw', args: [1, ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientCash', },

        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet2.address], }, // so pool size is big enough
        { send: 'eVaults.eTST.withdraw', args: [1, ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },


        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },

        { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(3);

            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(et.AddressZero);
            et.expect(logs[0].args.to).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.value).to.equal(et.eth(10));

            et.expect(logs[1].name).to.equal('Deposit');
            et.expect(logs[1].args.sender).to.equal(ctx.wallet.address);
            et.expect(logs[1].args.owner).to.equal(ctx.wallet.address);
            et.expect(logs[1].args.assets).to.equal(et.eth(10));
            et.expect(logs[1].args.shares).to.equal(et.eth(10));
            // TODO add other events
        }},

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: et.eth(10), },

        // some unrelated token not affected
        { call: 'tokens.TST2.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], equals: 0, },

        { send: 'eVaults.eTST.withdraw', args: [et.eth(10).add(1), ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },

        { send: 'eVaults.eTST.deposit', args: [1, ctx.wallet.address], expectError: 'TransferFromFailed', },

        { send: 'eVaults.eTST.withdraw', args: [et.eth(10), ctx.wallet.address, ctx.wallet.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(3);

            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.to).to.equal(et.AddressZero);
            et.expect(logs[0].args.value).to.equal(et.eth(10));

            et.expect(logs[1].name).to.equal('Withdraw');
            et.expect(logs[1].args.sender).to.equal(ctx.wallet.address);
            et.expect(logs[1].args.receiver).to.equal(ctx.wallet.address);
            et.expect(logs[1].args.owner).to.equal(ctx.wallet.address);
            et.expect(logs[1].args.assets).to.equal(et.eth(10));
            et.expect(logs[1].args.shares).to.equal(et.eth(10));
        }},

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },

        { send: 'eVaults.eTST.withdraw', args: [1, ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },
    ],
})


.test({
    desc: "multiple deposits",
    actions: ctx => [
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet2.address], },

        // first user
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: et.eth(10), },

        // second user
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], equals: et.eth(10), },

        // Total supply is the two balances above
        { call: 'eVaults.eTST.totalSupply', equals: et.eth(10).add(et.eth(10)), },

        { from: ctx.wallet, send: 'eVaults.eTST.withdraw', args: [et.eth(10).add(1), ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },
        { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.eth(10).add(1), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_InsufficientBalance', },

        { from: ctx.wallet, send: 'eVaults.eTST.withdraw', args: [et.eth(10), ctx.wallet.address, ctx.wallet.address], },

        { from: ctx.wallet, send: 'eVaults.eTST.withdraw', args: [1, ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },
        { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.eth('20'), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_InsufficientCash', },

        { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.eth(4), ctx.wallet2.address, ctx.wallet2.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.eth('6.00001'), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_InsufficientCash', },

        { from: ctx.wallet2, send: 'eVaults.eTST.withdraw', args: [et.eth(6), ctx.wallet2.address, ctx.wallet2.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], equals: 0, },
        { call: 'eVaults.eTST.totalSupply', equals: 0, },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet2.address], equals: et.eth(10), },
    ],
})


.test({
    desc: "deposit/withdraw maximum",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [et.MaxUint256, ctx.wallet.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },

        { send: 'eVaults.eTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },
    ],
})

.run();

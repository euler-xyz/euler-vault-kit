const et = require('./lib/eTestLib');

et.testSet({
    desc: "transfer eVault balances, without interest",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, 1000], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        }

        return actions;
    },
})


.test({
    desc: "basic transfer",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 0, },

        { send: 'eVaults.eTST.transfer', args: [ctx.wallet2.address, 400], onLogs: allLogs => {
            let logs = allLogs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);

            et.expect(logs.length).to.equal(2);

            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.to).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.value.toNumber()).to.equal(400);

            et.expect(logs[1].name).to.equal('VaultStatus');
        }},

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 600, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 400, },
    ],
})


.test({
    desc: "transfer with zero amount is a no-op",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { send: 'eVaults.eTST.transfer', args: [ctx.wallet2.address, 500], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 500, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 500, },

        // no-op, balances of sender and recipient not affected
        { send: 'eVaults.eTST.transfer', args: [ctx.wallet2.address, 0], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(2);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[1].name).to.equal('VaultStatus');
        }}, 
    ],
})


.test({
    desc: "transfer between sub-accounts with zero amount is a no-op",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { send: 'eVaults.eTST.transfer', args: [ctx.wallet2.address, 500], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 500, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 500, },

        { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), 200], },

        // no-op, balances of sender and recipient not affected
        { send: 'eVaults.eTST.transferFrom', args: [et.getSubAccount(ctx.wallet.address, 1), et.getSubAccount(ctx.wallet.address, 255), 0], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(2);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[1].name).to.equal('VaultStatus');
        }},  

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 300, },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: 200, },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 255)], assertEql: 0, },
    ],
})


.test({
    desc: "transfer max",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        // MAX_UINT is *not* a short-cut for this:
        { send: 'eVaults.eTST.transfer', args: [ctx.wallet2.address, et.MaxUint256], expectError: 'E_AmountTooLargeToEncode', },

        { send: 'eVaults.eTST.transferFromMax', args: [ctx.wallet.address, ctx.wallet2.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(2);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.to).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.value.toNumber()).to.equal(1000);
        }},

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 1000, },

        { send: 'eVaults.eTST.transferFromMax', args: [ctx.wallet.address, ctx.wallet2.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(2);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[1].name).to.equal('VaultStatus');
        }},

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 1000, },
    ],
})



.test({
    desc: "approval, max",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet2.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 1000, },
        { call: 'eVaults.eTST.allowance', args: [ctx.wallet2.address, ctx.wallet.address], assertEql: 0, },

        { from: ctx.wallet1, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 300], expectError: 'E_InsufficientAllowance', },
        { from: ctx.wallet3, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 300], expectError: 'E_InsufficientAllowance', },

        { from: ctx.wallet2, send: 'eVaults.eTST.approve', args: [ctx.wallet.address, et.MaxUint256], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].name).to.equal('Approval');
            et.expect(logs[0].args.owner).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.spender).to.equal(ctx.wallet.address);
            et.assert(logs[0].args.value.eq(et.MaxUint256));
        }},
        { call: 'eVaults.eTST.allowance', args: [ctx.wallet2.address, ctx.wallet.address], assertEql: et.MaxUint256, },

        { from: ctx.wallet1, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 300], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.expect(logs.length).to.equal(2);
            et.expect(logs[0].name).to.equal('Transfer');
            et.expect(logs[0].args.from).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.to).to.equal(ctx.wallet3.address);
            et.expect(logs[0].args.value.toNumber()).to.equal(300);
        }},

        { from: ctx.wallet3, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 100], expectError: 'E_InsufficientAllowance', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 700, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], assertEql: 300, },
        { call: 'eVaults.eTST.allowance', args: [ctx.wallet2.address, ctx.wallet.address], assertEql: et.MaxUint256, },
    ],
})



.test({
    desc: "approval, limited",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet2.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.approve', args: [ctx.wallet.address, 200], onLogs: logs => {
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].address).to.equal(ctx.contracts.eVaults.eTST.address);
            et.expect(logs[0].args.owner).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.spender).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.value.toNumber()).to.equal(200);
        }},
        { call: 'eVaults.eTST.allowance', args: [ctx.wallet2.address, ctx.wallet.address], assertEql: 200, },

        { from: ctx.wallet1, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 201], expectError: 'E_InsufficientAllowance', },
        { from: ctx.wallet1, send: 'eVaults.eTST.transferFrom', args: [ctx.wallet2.address, ctx.wallet3.address, 150], onLogs: logs => {
            logs = logs.filter(l => l.name === 'Approval');
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].address).to.equal(ctx.contracts.eVaults.eTST.address);
            et.expect(logs[0].args.owner).to.equal(ctx.wallet2.address);
            et.expect(logs[0].args.spender).to.equal(ctx.wallet.address);
            et.expect(logs[0].args.value.toNumber()).to.equal(50);
        }},

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: 850, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], assertEql: 150, },
        { call: 'eVaults.eTST.allowance', args: [ctx.wallet2.address, ctx.wallet.address], assertEql: 50, },
    ],
})



.test({
    desc: "transfer between sub-accounts",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), 700], },
        // sub-accounts are not recognized by the vault itself
        { send: 'eVaults.eTST.transferFrom', args: [et.getSubAccount(ctx.wallet.address, 1), et.getSubAccount(ctx.wallet.address, 255), 400], expectError: 'E_InsufficientAllowance', },
        { action: 'sendBatch', batch: [
            { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST.approve', args: [ctx.wallet.address, 500], },
        ], },
        { send: 'eVaults.eTST.transferFrom', args: [et.getSubAccount(ctx.wallet.address, 1), et.getSubAccount(ctx.wallet.address, 255), 400], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 300, },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: 300, },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 255)], assertEql: 400, },
        { call: 'eVaults.eTST.allowance', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.wallet.address], assertEql: 100, },
    ],
})


.test({
    desc: "self-transfer with valid amount",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        // revert on self-transfer of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.transfer', args: [ctx.wallet.address, 10], expectError: 'E_SelfTransfer', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },
    ],
})


.test({
    desc: "self-transfer with zero amount",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        // revert on self-transfer of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.transfer', args: [ctx.wallet.address, 0], expectError: 'E_SelfTransfer', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },
    ],
})


.test({
    desc: "self-transfer with max amount exceeding balance",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        // revert on self-transfer of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.transfer', args: [ctx.wallet.address, et.MaxUint256], expectError: 'E_SelfTransfer', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },
    ],
})


.run();

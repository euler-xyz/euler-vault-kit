const et = require('./lib/eTestLib');

et.testSet({
    desc: "self-approve eVaults",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, 1000], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        }

        return actions;
    },
})


.test({
    desc: "self-approve with valid amount",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },

        // revert on self-approve of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.approve', args: [ctx.wallet.address, 10], expectError: 'E_SelfApproval', },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },
    ],
})


.test({
    desc: "self-approve with zero amount",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },

        // revert on self-approve of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.approve', args: [ctx.wallet.address, 0], expectError: 'E_SelfApproval', },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },
    ],
})


.test({
    desc: "self-approve with max amount exceeding balance",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },

        // revert on self-approve of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.approve', args: [ctx.wallet.address, et.MaxUint256], expectError: 'E_SelfApproval', },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, ctx.wallet.address], assertEql: 0, },
    ],
})


.test({
    desc: "self-approve for subAccount with valid amount",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [1000, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1000, },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, et.getSubAccount(ctx.wallet.address, 1)], assertEql: 0, },

        // revert on self-approve of eVault
        { from: ctx.wallet, send: 'eVaults.eTST.approve', args: [et.getSubAccount(ctx.wallet.address, 1), 10], },

        { call: 'eVaults.eTST.allowance', args: [ctx.wallet.address, et.getSubAccount(ctx.wallet.address, 1)], assertEql: 10, },
    ],
})


.run();
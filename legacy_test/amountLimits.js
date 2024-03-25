const et = require('./lib/eTestLib');

const maxSaneAmount = ethers.BigNumber.from(2).pow(112).sub(1);


et.testSet({
    desc: "maximum amount values",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.MaxUint256.div(3)], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });

            actions.push({ from, send: 'tokens.TST6.mint', args: [from.address, et.MaxUint256.div(3)], });
            actions.push({ from, send: 'tokens.TST6.approve', args: [ctx.contracts.eVaults.eTST6.address, et.MaxUint256,], });
        }

        return actions;
    },
})

.test({
    desc: "deposits and withdrawals",
    actions: ctx => [
        // Reads balanceOf on TST, which returns amount too large
        { send: 'eVaults.eTST.deposit', args: [et.MaxUint256, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // Specifies direct amount too large
        { send: 'eVaults.eTST.deposit', args: [et.MaxUint256.sub(1), ctx.wallet.address], expectError: 'E_AmountTooLarge', },
        { send: 'eVaults.eTST.withdraw', args: [et.MaxUint256.sub(1), ctx.wallet.address, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // One too large
        { send: 'eVaults.eTST.deposit', args: [maxSaneAmount.add(1), ctx.wallet.address], expectError: 'E_AmountTooLarge', },
        { send: 'eVaults.eTST.withdraw', args: [maxSaneAmount.add(1), ctx.wallet.address, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // Ok after reducing by 1
        { send: 'eVaults.eTST.deposit', args: [maxSaneAmount, ctx.wallet.address], },

        // Now another deposit to push us over the top
        { send: 'eVaults.eTST.deposit', args: [1, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // And from another account, poolSize will be too large
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [1, ctx.wallet2.address], expectError: 'E_AmountTooLarge', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: maxSaneAmount, },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: maxSaneAmount, },
        { call: 'eVaults.eTST.totalSupply', equals: maxSaneAmount, },
        { call: 'eVaults.eTST.totalAssets', equals: maxSaneAmount, },

        // Withdraw exact balance
        { action: 'snapshot' },
        { send: 'eVaults.eTST.withdraw', args: [maxSaneAmount, ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.totalSupply', equals: 0, },
        { call: 'eVaults.eTST.totalAssets', equals: 0, },

        { action: 'revert' },

        // redeem max for full balance
        { send: 'eVaults.eTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        // check balances
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.totalSupply', equals: 0, },
        { call: 'eVaults.eTST.totalAssets', equals: 0, },
    ],
})


.test({
    desc: "lower decimals",
    actions: ctx => [
        { send: 'tokens.TST10.mint', args: [ctx.wallet.address, et.MaxUint256], },
        { send: 'tokens.TST10.approve', args: [ctx.contracts.eVaults.eTST10.address, et.MaxUint256,], },

        // Reads balanceOf on TST, which returns amount too large
        { send: 'eVaults.eTST10.deposit', args: [et.MaxUint256, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // Specifies direct amount too large
        { send: 'eVaults.eTST10.deposit', args: [et.MaxUint256.sub(1), ctx.wallet.address], expectError: 'E_AmountTooLarge', },
        { send: 'eVaults.eTST10.withdraw', args: [et.MaxUint256.sub(1), ctx.wallet.address, ctx.wallet.address], expectError: 'E_AmountTooLarge', },

        // One too large
        { send: 'eVaults.eTST10.deposit', args: [maxSaneAmount.add(1), ctx.wallet.address],
          expectError: 'E_AmountTooLarge', },
        { send: 'eVaults.eTST10.withdraw', args: [maxSaneAmount.add(1), ctx.wallet.address, ctx.wallet.address],
          expectError: 'E_AmountTooLarge', },

        // OK, by 1
        { send: 'eVaults.eTST10.deposit', args: [maxSaneAmount, ctx.wallet.address], },
        { call: 'eVaults.eTST10.balanceOf', args: [ctx.wallet.address], equals: maxSaneAmount, },
        { call: 'eVaults.eTST10.maxWithdraw', args: [ctx.wallet.address], equals: maxSaneAmount, },
        { call: 'eVaults.eTST10.totalSupply', equals: maxSaneAmount, },
        { call: 'eVaults.eTST10.totalAssets', equals: maxSaneAmount, },

        // Withdraw exact balance
        { action: 'snapshot' },
        { send: 'eVaults.eTST10.withdraw', args: [maxSaneAmount, ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST10.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST10.maxWithdraw', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST10.totalSupply', equals: 0, },
        { call: 'eVaults.eTST10.totalAssets', equals: 0, },
        
        { action: 'revert' },

        // withdraw max for full balance
        { send: 'eVaults.eTST10.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
        
        // check balances
        { call: 'eVaults.eTST10.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST10.maxWithdraw', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST10.totalSupply', equals: 0, },
        { call: 'eVaults.eTST10.totalAssets', equals: 0, },
    ],
})



.test({
    desc: "deposit over the asset limit",
    actions: ctx => [
        // configure TST to transfer requested amount + 1 wei 
        { send: 'tokens.TST.configure', args: ['transfer/inflationary', et.abiEncode(['uint256'], [1])], }, 
        { send: 'eVaults.eTST.deposit', args: [maxSaneAmount, ctx.wallet.address],  },

        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [1, ctx.wallet2.address], expectError: 'E_AmountTooLarge', },
    ],
})


.test({
    desc: "increaseBalance results in totalBalances being too large",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [maxSaneAmount, ctx.wallet.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.loop', args: [10, ctx.wallet2.address], expectError: 'E_ControllerDisabled', },

        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.loop', args: [10, ctx.wallet2.address], expectError: 'E_AmountTooLargeToEncode', },
    ],
})



.run();

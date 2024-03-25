const et = require('./lib/eTestLib');

et.testSet({
    desc: "gas tests",

    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
        }

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
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
    desc: "simple gas",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(.4), ctx.wallet2.address], },


        { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [et.eth(50), ctx.wallet3.address], },
        { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST2.address], },
        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet3.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.repay', args: [et.eth(.1), ctx.wallet3.address], },
    ],
})




.run();

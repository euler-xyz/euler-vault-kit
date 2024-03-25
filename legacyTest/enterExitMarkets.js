const et = require('./lib/eTestLib');


et.testSet({
    desc: "entering/exiting markets",

    preActions: ctx => {
        let actions = [];

        // Need to setup uniswap prices for exitMarket tests

        actions.push({ action: 'checkpointTime', });

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.01', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.05', });

        actions.push({ action: 'jumpTime', time: 31*60, });

        return actions;
    },
})


.test({
    desc: "normal flow",
    actions: ctx => [
        { call: 'evc.getCollaterals', args: [ctx.wallet.address], assertEql: [], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eWETH.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address, ctx.contracts.eVaults.eWETH.address], },

        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eWETH.address], },

        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eWETH.address], },

        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eWETH.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [], },
    ],
})


.test({
    desc: "exit un-entered market",
    actions: ctx => [
        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { send: 'evc.disableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eWETH.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address], },
    ],
})


.test({
    desc: "try to enter market already in",
    actions: ctx => [
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address], },

        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getCollaterals', args: [ctx.wallet.address],
          assertEql: [ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eTST2.address], },
    ],
})


.run();

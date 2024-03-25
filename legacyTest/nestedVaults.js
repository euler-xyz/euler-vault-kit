const et = require('./lib/eTestLib');
// const metadata = (asset, riskManager) => ethers.utils.solidityPack(['address'], [asset])

et.testSet({
    desc: "nested vaults",
    preActions: ctx => [

        { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.eVaults.eTST.address)], onLogs: async logs => {
            let log = logs.find(l => l.name === 'ProxyCreated');
            ctx.contracts.enVaults = { enTST: await ethers.getContractAt('EVault', log.args.proxy) };
            await ctx.contracts.oracles.priceOracleCore.initPricingConfig(log.args.proxy, 18, true)
        }},
        ...[ctx.wallet, ctx.wallet2, ctx.wallet3, ctx.wallet4].flatMap(from => [
            { from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], },
            { from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], },
            { from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], },
            { from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], },
        ])
    ],
})


.test({
    desc: "deposit withdraw",
    actions: ctx => [
        { callStatic: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], equals: et.eth(10)},

        { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], },
        { send: 'eVaults.eTST.approve', args: [ctx.contracts.enVaults.enTST.address, et.MaxUint256], },

        { send: 'enVaults.enTST.deposit', args: [et.eth(10), ctx.wallet.address], },

        { call: 'enVaults.enTST.balanceOf', args: [ctx.wallet.address], equals: et.eth(10), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0, },

        { send: 'enVaults.enTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        { call: 'enVaults.enTST.balanceOf', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(10), '0.00000000001'], },
    ],
})


.test({
    desc: "basic borrow and repay",
    actions: ctx => [
        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet2.address], },
            { send: 'eVaults.eTST.approve', args: [ctx.contracts.enVaults.enTST.address, et.MaxUint256], },

            { send: 'enVaults.enTST.deposit', args: [et.eth(10), ctx.wallet2.address], },
        ]},
        // deposit collateral
        // { send: 'riskManagers.riskManagerNested.activateExternalMarket', args: [ctx.contracts.eVaults.eTST2.address], },
        { send: 'eVaults.eTST2.deposit', args: [et.eth(20), ctx.wallet.address], },

        // try to borrow
        { send: 'enVaults.enTST.borrow', args: [et.eth(5), ctx.wallet.address], expectError: 'E_ControllerDisabled', },

        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.enVaults.enTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

        { send: 'enVaults.enTST.borrow', args: [et.eth(5), ctx.wallet.address], expectError: 'E_AccountLiquidity', },

        { send: 'enVaults.enTST.setLTV', args: [ctx.contracts.eVaults.eTST2.address, 0.8 * 1e4, 0], },

        // successfull borrow
        { send: 'enVaults.enTST.borrow', args: [et.eth(5), ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: et.eth(5) },
        { call: 'enVaults.enTST.debtOf', args: [ctx.wallet.address], equals: et.eth(5) },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(100), },

        // withdraw from base
        { send: 'eVaults.eTST.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0 },
        { call: 'enVaults.enTST.debtOf', args: [ctx.wallet.address], equals: [et.eth(5), '0.000001'] }, // interest is accruing
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(105), '0.00000000001'], },

        // transfer excess collateral
        { send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth(19)], expectError: 'E_AccountLiquidity', }, // too much
        { send: 'eVaults.eTST2.transfer', args: [ctx.wallet3.address, et.eth(10)], },


        // liquidate nested liability
        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '1.65', },

        { call: 'enVaults.enTST.accountLiquidity', args: [ctx.wallet.address, false], onResult: r => {
            ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue);
            et.equals(r.collateralValue / r.liabilityValue, 0.969, 0.001);
        }, },

        { from: ctx.wallet4, send: 'evc.enableController', args: [ctx.wallet4.address, ctx.contracts.enVaults.enTST.address], },
        { from: ctx.wallet4, send: 'evc.enableCollateral', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST2.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST2.deposit', args: [et.eth(10), ctx.wallet4.address], },

        { call: 'enVaults.enTST.checkLiquidation', args: [ctx.wallet4.address, ctx.wallet.address, ctx.contracts.eVaults.eTST2.address],
            onResult: async r => {
                ctx.stash.maxRepay = r.maxRepay;
                ctx.stash.maxYield = r.maxYield;

                const yieldAssets = await ctx.contracts.eVaults.eTST2.convertToAssets(r.maxYield);
                const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST2.address, ctx.contracts.tokens.WETH.address)
                const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST.address, ctx.contracts.tokens.WETH.address)
                et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000001')
            },
        },

        { from: ctx.wallet4, send: 'enVaults.enTST.liquidate', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address, () => ctx.stash.maxRepay, 0], },

        { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet4.address], equals: () => [ctx.stash.maxYield.add(et.eth(10)), '0.000001'], },
        { call: 'enVaults.enTST.debtOf', args: [ctx.wallet4.address], equals: () => [ctx.stash.maxRepay, '0.000001'], },


        // repay
        { from: ctx.wallet4, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet4.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST.approve', args: [ctx.contracts.enVaults.enTST.address, et.MaxUint256], },

        { from: ctx.wallet4, send: 'enVaults.enTST.repay', args: [et.MaxUint256, ctx.wallet4.address], },

        { call: 'enVaults.enTST.debtOf', args: [ctx.wallet4.address], equals: 0, },
    ],
})


.test({
    desc: "repay when not healthy",
    actions: ctx => [
        { from: ctx.wallet2, action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet2.address], },
            { send: 'eVaults.eTST.approve', args: [ctx.contracts.enVaults.enTST.address, et.MaxUint256], },

            { send: 'enVaults.enTST.deposit', args: [et.eth(10), ctx.wallet2.address], },
        ]},
        { send: 'eVaults.eTST2.deposit', args: [et.eth(10), ctx.wallet.address], },

        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.enVaults.enTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

        { send: 'enVaults.enTST.setLTV', args: [ctx.contracts.eVaults.eTST2.address, 0.8 * 1e4, 0], },
        { send: 'enVaults.enTST.borrow', args: [et.eth(5), ctx.wallet.address], },

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '1.65', },

        // account unhealthy
        { call: 'enVaults.enTST.accountLiquidity', args: [ctx.wallet.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.969, 0.001);
        }, },

        { send: 'eVaults.eTST.approve', args: [ctx.contracts.enVaults.enTST.address, et.MaxUint256], },
        { send: 'enVaults.enTST.repay', args: [et.eth(5), ctx.wallet.address], },

        // unhealthy again

        { send: 'enVaults.enTST.borrow', args: [et.eth(3), ctx.wallet.address], },
        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '3', },

        { call: 'enVaults.enTST.accountLiquidity', args: [ctx.wallet.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.888, 0.001);
        }, },

        // repay without going back to health
        // Partial repay fails because health check is scheduled on the account by nested transferFrom from pullTokens
        { send: 'enVaults.enTST.repay', args: [et.eth(0.1), ctx.wallet.address],  expectError: 'E_AccountLiquidity'},

        // repay to HS >= 1 succeeds
        { send: 'enVaults.enTST.repay', args: [et.eth(3), ctx.wallet.address], },

        { call: 'enVaults.enTST.accountLiquidity', args: [ctx.wallet.address, false], onResult: r => {
            et.expect(r.collateralValue / r.liabilityValue).to.be.gte(1)
        }, },
    ],
})

// try to borrow with nothing in base


.run();

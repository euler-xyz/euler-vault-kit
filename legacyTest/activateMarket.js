const et = require('./lib/eTestLib');

et.testSet({
    desc: "activating markets with core risk manager",
})

// .test({
//     desc: "re-activate is no-op",
//     actions: ctx => [
//         { from: ctx.wallet, send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.UTST.address)], onLogs: logs => {
//             ctx.stash.eVaultAddr = logs.find(l => l.name === 'ProxyCreated').args.proxy;
//         }},

//         { 
//             from: ctx.wallet, send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.UTST.address)],
//             expectError: 'E_UnderlyingActivated',
//         },
//     ],
// })


.test({
    desc: "invalid contracts",
    actions: ctx => [
        { from: ctx.wallet, send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(et.AddressZero)], expectError: 'E_BadAddress', },
        { from: ctx.wallet, send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.wallet.address)], expectError: 'E_BadAddress', },
    ],
})

// TODO move to oracle?
// .test({
//     desc: "no uniswap pool",
//     actions: ctx => [
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], expectError: 'POC_NoUniswapPoolAvailable', },
//     ],
// })


// .test({
//     desc: "uniswap pool not initiated",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         async () => {
//             await (await ctx.contracts.uniswapPools['TST4/WETH'].mockSetThrowNotInitiated(true)).wait();
//         },
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], expectError: 'POC_UniswapPoolNotInited', },
//     ],
// })


// .test({
//     desc: "uniswap pool other error",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         async () => {
//             await (await ctx.contracts.uniswapPools['TST4/WETH'].mockSetThrowOther(true)).wait();
//         },
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], expectError: /POC_Uniswap\(\"OTHER\"\)/, },
//     ],
// })


// .test({
//     desc: "uniswap pool empty error",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         async () => {
//             await (await ctx.contracts.uniswapPools['TST4/WETH'].mockSetThrowEmpty(true)).wait();
//         },
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], expectError: 'POC_EmptyError', },
//     ],
// })


// .test({
//     desc: "select second fee uniswap pool",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.LOW, },
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], },
//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST4.address], onResult: r => {
//             et.expect(r.pricingParameters).to.equal(et.FeeAmount.LOW);
//         }, },
//     ],
// })


// .test({
//     desc: "select third fee uniswap pool",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.HIGH, },
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], },
//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST4.address], onResult: r => {
//             et.expect(r.pricingParameters).to.equal(et.FeeAmount.HIGH);
//         }, },
//     ],
// })



// .test({
//     desc: "choose pool with best liquidity",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [6000], },

//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.LOW, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [9000], },

//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.HIGH, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [7000], },

//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], },
//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST4.address], onResult: r => {
//             et.expect(r.pricingParameters).to.equal(et.FeeAmount.LOW);
//         }, },
//     ],
// })


// .test({
//     desc: "choose pool with best liquidity, 2",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [6000], },

//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.HIGH, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [7000], },

//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], },
//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST4.address], onResult: r => {
//             et.expect(r.pricingParameters).to.equal(et.FeeAmount.HIGH);
//         }, },
//     ],
// })


// .test({
//     desc: "choose pool with best liquidity, 3",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [7000], },

//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.HIGH, },
//         { send: 'uniswapPools.TST4/WETH.mockSetLiquidity', args: [6000], },

//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], },
//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST4.address], onResult: r => {
//             et.expect(r.pricingParameters).to.equal(et.FeeAmount.MEDIUM);
//         }, },
//     ],
// })


// .test({
//     desc: "pool address computation",
//     actions: ctx => [
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.MEDIUM, },
//         { action: 'createUniswapPool', pair: 'TST4/WETH', fee: et.FeeAmount.LOW, },

//         // Make it so that getPool(LOW) returns the pool for MEDIUM, to cause the CREATE2 address computation to fail

//         { action: 'cb', cb: async () => {
//             let lowPool = await ctx.contracts.uniswapV3Factory.getPool(ctx.contracts.tokens.TST4.address, ctx.contracts.tokens.WETH.address, et.FeeAmount.LOW);

//             await ctx.contracts.uniswapV3Factory.setPoolAddress(ctx.contracts.tokens.TST4.address, ctx.contracts.tokens.WETH.address, et.FeeAmount.MEDIUM, lowPool);
//         }, },

//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.tokens.TST4.address)], expectError: 'POC_BadUniswapPoolAddress'},
//     ],
// })


.run();

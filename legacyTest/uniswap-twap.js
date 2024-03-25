// TODO

// const et = require('./lib/eTestLib');
// const metadata = (asset, riskManager) => ethers.utils.solidityPack(['address', 'address'], [asset, riskManager])

// let tests = et.testSet({
//     desc: "uniswap3 twap",
//     timeout: 100_000,
//     fixture: "testing-real-uniswap",
// })


// .test({
//     desc: "integration with uniswap3 core",
//     actions: ctx => [
//         { send: 'tokens.TST.mint', args: [ctx.wallet.address, et.eth(100)], },
//         { send: 'tokens.TST.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

//         { send: 'tokens.WETH.mint', args: [ctx.wallet.address, et.eth(100)], },
//         // { send: 'tokens.WETH.approve', args: [ctx.contracts.eVaults.eWETH.address, et.MaxUint256,], },
//         { send: 'tokens.WETH.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

//         // Uniswap pool has been created, but not init'ed

//         { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens.TST.address, ctx.contracts.riskManagers.riskManagerCore.address)], expectError: 'POC_UniswapPoolNotInited', },

//         // Init uniswap pool, euler pool still not activated

//         { send: 'uniswapPools.TST/WETH.initialize', args: [et.ratioToSqrtPriceX96(et.c1e18, et.c1e18)], },
//         { action: 'checkpointTime', },

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(0);
//             et.expect(r.observationCardinality).to.equal(1);
//             et.expect(r.observationCardinalityNext).to.equal(1);
//         }},

//         // Activate euler market

//         { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens.TST.address, ctx.contracts.riskManagers.riskManagerCore.address), ], },
//         { action: 'cb', cb: async () => {
//             let eVaultAddr = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(ctx.contracts.tokens.TST.address);
//             ctx.contracts.eVaults['eTST'] = await ethers.getContractAt('EVault', eVaultAddr);
//         }},

//         // No initialized ticks, so unable to get a price

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.equals(r.currPrice, 1);
//             et.expect(r.twapPeriod).to.equal(await ctx.lastBlockTimestamp() - ctx.lastCheckpointTime);
//             et.equals(r.twap, 1);
//         }},

//         // Just testing that the minimal getPrice() also works
//         { action: 'getPriceMinimal', underlying: 'TST', onResult: async (r) => {
//             et.expect(r.currPrice).to.equal(undefined);
//             et.expect(r.twapPeriod).to.equal(await ctx.lastBlockTimestamp() - ctx.lastCheckpointTime);
//             et.equals(r.twap, 1);
//         }},

//         // observationCardinalityNext was increased by activate

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(0);
//             et.expect(r.observationCardinality).to.equal(1);
//             et.expect(r.observationCardinalityNext).to.equal(144);
//         }},

//         // Supply some liquidity (assuming tickSpacing of 60): Math.ceil(-887272 / 60) * 60 = -887220, Math.floor(887272 / 60) * 60 = 887220

//         { send: 'simpleUniswapPeriphery.mint', args: [() => ctx.contracts.uniswapPools["TST/WETH"].address, ctx.wallet.address, -887220, 887220, et.eth('1.0')], },

//         // The mint increases the observationIndex, and is able to bump up the cardinality since the
//         // index was at the last element (buffer was size 1).

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(1);
//             et.expect(r.observationCardinality).to.equal(144);
//             et.expect(r.observationCardinalityNext).to.equal(144);
//         }},

//         // getPrice still succeeds, twap is longer

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.equals(r.currPrice, 1);
//             et.expect(r.twapPeriod).to.equal(await ctx.lastBlockTimestamp() - ctx.lastCheckpointTime);
//             et.equals(r.twap, 1);
//         }},

//         // Mine a couple blocks to increase timestamp

//         { action: 'mineEmptyBlock', },
//         { action: 'mineEmptyBlock', },

//         // Now do a swap. First define a utility to do this:

//         { action: 'cb', cb: async () => {
//             ctx.stash.doSwap = async () => {
//                 await ctx.doUniswapSwap(ctx.wallet, 'TST', 'sell', et.eth(0.001), 0.1);
//             };
//         }},

//         // And do it:

//         { action: 'cb', cb: async () => { await ctx.stash.doSwap(); }},

//         // Index now increases to 2:

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(2);
//             et.expect(r.observationCardinality).to.equal(144);
//         }},

//         // currPrice is updated, but TWAP not yet

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.equals(r.currPrice, 0.9980, .0001);
//             let now = await ctx.lastBlockTimestamp();
//             et.expect(r.twapPeriod).to.equal(now - ctx.lastCheckpointTime);
//             et.equals(r.twap, 1); // un-affected since trade happened in most recent block

//             ctx.stash.timeA = ctx.lastCheckpointTime;
//             ctx.stash.timeB = now;
//         }},
//         { action: 'checkpointTime', },

//         // Jump forward 5 seconds

//         { action: 'jumpTimeAndMine', time: 5, },

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.equals(r.currPrice, 0.9980, .0001);
//             let currPrice = parseFloat(et.ethers.utils.formatEther(r.currPrice));

//             let now = await ctx.lastBlockTimestamp();
//             et.expect(r.twapPeriod).to.equal(now - ctx.stash.timeA);

//             // Confirm that twap is the average (approximate it with arithmetic mean)

//             let expectedTwap = ((1 * (ctx.stash.timeB - ctx.stash.timeA)) + (currPrice * (now - ctx.stash.timeB))) / r.twapPeriod.toNumber();
//             et.equals(r.twap, expectedTwap, 0.001); // FIXME: there is some time-related non-determinism in this test, fix this after cardinality update branch merged
//         }},

//         // A bunch more swaps

//         { action: 'cb', cb: async () => {
//             for (let i = 0; i < 141; i++) {
//                 await ctx.stash.doSwap();
//             }
//         }},

//         // Now we've filled all observation

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(143);
//             et.expect(r.observationCardinality).to.equal(144);
//             et.expect(r.observationCardinalityNext).to.equal(144);
//         }},

//         // TWAP period is still from the start

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.expect(r.twapPeriod).to.equal(await ctx.lastBlockTimestamp() - ctx.stash.timeA);
//         }},

//         // One more trade to wrap it around

//         { action: 'cb', cb: async () => { await ctx.stash.doSwap(); }},

//         { call: 'uniswapPools.TST/WETH.slot0', args: [], onResult: async (r) => {
//             et.expect(r.observationIndex).to.equal(0);
//             et.expect(r.observationCardinality).to.equal(144);
//             et.expect(r.observationCardinalityNext).to.equal(144);
//         }, },

//         // Now the twap period is shorter

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.expect(r.twapPeriod).to.be.below(await ctx.lastBlockTimestamp() - ctx.stash.timeA);
//         }},

//         // If we fast forward, we can get a full twap:

//         { action: 'jumpTimeAndMine', time: 1800, },

//         { action: 'getPrice', underlying: 'TST', onResult: async (r) => {
//             et.expect(r.twapPeriod).to.equal(1800);
//         }},
//     ],
// })



// .test({
//     desc: "switch uniswap3 fee pool",
//     actions: ctx => [
//         // Initialize uniswap pool

//         { send: 'uniswapPools.TST/WETH.initialize', args: [et.ratioToSqrtPriceX96(et.c1e18, et.c1e18)], },

//         // Cannot set pool pricing configuration for non-active markets

//         { from: ctx.wallet, send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.WETH.address, 2, et.FeeAmount.LOW, 1800], expectError: 'POC_AssetNotInitialized', },

//         { from: ctx.wallet, send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, 2, et.FeeAmount.LOW, 1800], expectError: 'POC_AssetNotInitialized', },


//         // Activate euler market for TST token

//         { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens.TST.address, ctx.contracts.riskManagers.riskManagerCore.address)], },
//         { action: 'cb', cb: async () => {
//             let eVaultAddr = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(ctx.contracts.tokens.TST.address);
//             ctx.contracts.eVaults['eTST'] = await ethers.getContractAt('EVault', eVaultAddr);
//         }},
//         // Get current pool pricing configuration
//         // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and default pool fee

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [() => ctx.contracts.tokens.TST.address], onResult: r => {
//             et.expect(r).to.eql([2, et.DefaultUniswapFee]);
//         }},

//         // Set and get updated pool pricing configuration

//         // Check current governanor admin first

//         { call: 'riskManagers.riskManagerCore.getGovernorAdmin', onResult: r => {
//             et.expect(ctx.wallet.address).to.equal(r);
//         }},

//         // Set pricing configuration

//         { from: ctx.wallet, send: 'oracles.priceOracleCore.setPricingConfig', args: [() => ctx.contracts.tokens.TST.address, 2, et.FeeAmount.LOW, 1800], },

//         // Get current pool pricing configuration

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [() => ctx.contracts.tokens.TST.address], onResult: r => {
//             et.expect(r).to.eql([2, et.FeeAmount.LOW]);
//         }},
//     ],
// })


// .test({
//     desc: "token address ordering",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let wethAddr = ethers.BigNumber.from(ctx.contracts.tokens.WETH.address);
//             let tst2Addr = ethers.BigNumber.from(ctx.contracts.tokens.TST2.address);
//             let tst5Addr = ethers.BigNumber.from(ctx.contracts.tokens.TST5.address);
//             let tst6Addr = ethers.BigNumber.from(ctx.contracts.tokens.TST6.address);

//             et.assert(wethAddr.lt(tst2Addr), "weth < tst2");
//             et.assert(wethAddr.lt(tst5Addr), "weth < tst5"); 

//             et.assert(wethAddr.gt(tst6Addr), "weth > tst6");
//         }},
//     ],
// })


// .test({
//     desc: "6 decimals normalised to 18 decimals",
//     actions: ctx => [
//         { send: 'uniswapPools.TST2/WETH.initialize', args: [et.ratioToSqrtPriceX96(1, ethers.BigNumber.from(10).pow(18 - 6).mul(300))], },

//         { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens.TST2.address, ctx.contracts.riskManagers.riskManagerCore.address)], },
//         { action: 'cb', cb: async () => {
//             let eVaultAddr = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(ctx.contracts.tokens.TST2.address);
//             ctx.contracts.eVaults['eTST2'] = await ethers.getContractAt('EVault', eVaultAddr);
//         }},

//         { action: 'getPrice', underlying: 'TST2', onResult: async (r) => {
//             et.equals(r.currPrice, 300, '.0000000000001');
//             et.equals(r.twap, 300, '.1');
//         }},
//     ],
// })


// .test({
//     desc: "6 decimals normalised to 18 decimals, inverted",
//     actions: ctx => [
//         { send: 'uniswapPools.TST6/WETH.initialize', args: [et.ratioToSqrtPriceX96(ethers.BigNumber.from(10).pow(18 - 6).mul(300), 1)], },

//         { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens.TST6.address, ctx.contracts.riskManagers.riskManagerCore.address)], },
//         { action: 'cb', cb: async () => {
//             let eVaultAddr = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(ctx.contracts.tokens.TST6.address);
//             ctx.contracts.eVaults['eTST6'] = await ethers.getContractAt('EVault', eVaultAddr);
//         }},

//         { action: 'getPrice', underlying: 'TST6', onResult: async (r) => {
//             et.equals(r.currPrice, 300, '.0000000000001');
//             et.equals(r.twap, 300, '.1');
//         }},
//     ],
// });


// function oneE(pow) {
//     return et.ethers.BigNumber.from(10).pow(pow);
// }

// let priceTestCounter = 1;

// function priceTest(tok, a, b, expected, tolerance) {
//     tests.test({
//         desc: `priceTest ${tok} ${priceTestCounter++}`,
//         actions: ctx => [
//             { send: `uniswapPools.${tok}/WETH.initialize`, args: [et.ratioToSqrtPriceX96(a, b)], },

//             { send: 'genericFactory.createProxy', args: [true, metadata(ctx.contracts.tokens[tok].address, ctx.contracts.riskManagers.riskManagerCore.address)], },
//             { action: 'cb', cb: async () => {
//                 let eVaultAddr = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(ctx.contracts.tokens[tok].address);
//                 ctx.contracts.eVaults['e' + tok] = await ethers.getContractAt('EVault', eVaultAddr);
//             }},

//             { action: 'getPrice', underlying: tok, onResult: async (r) => {
//                 et.equals(r.currPrice, expected, tolerance);
//             }},
//         ],
//     });
// }




// // 6 decimal token, non-inverted

// // par
// priceTest('TST6', oneE(18-6), oneE(0),   oneE(18));

// // low prices
// priceTest('TST6', oneE(18-6), oneE(15),   oneE(0).mul(999));
// priceTest('TST6', oneE(18-6), oneE(16),   oneE(0).mul(99));
// priceTest('TST6', oneE(18-6), oneE(17),   oneE(0).mul(9));
// priceTest('TST6', oneE(18-6), oneE(18),   oneE(0));
// priceTest('TST6', oneE(18-6), oneE(19),   oneE(0));

// // high prices
// priceTest('TST6', oneE(18-6).mul(oneE(15)), oneE(0),   oneE(33));
// priceTest('TST6', oneE(18-6).mul(oneE(16)), oneE(0),   oneE(34));
// priceTest('TST6', oneE(18-6).mul(oneE(17)), oneE(0),   oneE(35));
// priceTest('TST6', oneE(18-6).mul(oneE(18)), oneE(0),   oneE(36));
// priceTest('TST6', oneE(18-6).mul(oneE(19)), oneE(0),   oneE(36));


// // 6 decimal token, inverted

// // par
// priceTest('TST2', oneE(0), oneE(18-6),   oneE(18), oneE(0));

// // low prices
// priceTest('TST2', oneE(15), oneE(18-6),   oneE(0).mul(999));
// priceTest('TST2', oneE(16), oneE(18-6),   oneE(0).mul(99));
// priceTest('TST2', oneE(17), oneE(18-6),   oneE(0).mul(9));
// priceTest('TST2', oneE(18), oneE(18-6),   oneE(0));
// priceTest('TST2', oneE(19), oneE(18-6),   oneE(0));

// // high prices
// priceTest('TST2', oneE(0), oneE(18-6).mul(oneE(15)),   oneE(36).div(999));
// priceTest('TST2', oneE(0), oneE(18-6).mul(oneE(16)),   oneE(36).div(99));
// priceTest('TST2', oneE(0), oneE(18-6).mul(oneE(17)),   oneE(36).div(9));
// priceTest('TST2', oneE(0), oneE(18-6).mul(oneE(18)),   oneE(36));
// priceTest('TST2', oneE(0), oneE(18-6).mul(oneE(19)),   oneE(36));



// // 0 decimal token, inverted

// // par
// priceTest('TST5', oneE(0), oneE(18-0),   oneE(18), oneE(0));

// // low prices
// priceTest('TST5', oneE(15), oneE(18-0),   oneE(0).mul(999));
// priceTest('TST5', oneE(16), oneE(18-0),   oneE(0).mul(99));
// priceTest('TST5', oneE(17), oneE(18-0),   oneE(0).mul(9));
// priceTest('TST5', oneE(18), oneE(18-0),   oneE(0));
// priceTest('TST5', oneE(19), oneE(18-0),   oneE(0));

// // high prices
// priceTest('TST5', oneE(0), oneE(18-0).mul(oneE(15)),   oneE(36).div(999));
// priceTest('TST5', oneE(0), oneE(18-0).mul(oneE(16)),   oneE(36).div(99));
// priceTest('TST5', oneE(0), oneE(18-0).mul(oneE(17)),   oneE(36).div(9));
// priceTest('TST5', oneE(0), oneE(18-0).mul(oneE(18)),   oneE(36));
// priceTest('TST5', oneE(0), oneE(18-0).mul(oneE(19)),   oneE(36));



// tests.run();

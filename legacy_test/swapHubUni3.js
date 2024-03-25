// const et = require('./lib/eTestLib');
// const scenarios = require('./lib/scenarios');

// const deposit = (ctx, token, wallet = ctx.wallet, subAccountId = 0, amount = 100, decimals = 18) => [
//     { from: wallet, send: `tokens.${token}.mint`, args: [wallet.address, et.units(amount, decimals)], },
//     { from: wallet, send: `tokens.${token}.approve`, args: [ctx.contracts.eVaults['e' + token].address, et.MaxUint256,], },
//     { from: wallet, send: `eVaults.e${token}.deposit`, args: [et.MaxUint256, wallet.address], },
// ];

// const setupInterestRates = ctx => [
//     { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmLinear', },
//     { action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmLinear', },
//     { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmLinear', },
//     { action: 'setInterestRateModel', underlying: 'TST4', irm: 'irmLinear', },

//     ...deposit(ctx, 'TST'),
//     ...deposit(ctx, 'TST4', ctx.wallet, 0, 100, 6),
//     ...deposit(ctx, 'WETH'),


//     { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.contracts.eVaults.eTST4.address], },

//     ...[ctx.wallet2, ctx.wallet3, ctx.wallet4].flatMap(w => [
//         ...deposit(ctx, 'TST3', w, 0, 200),
//         { from: w, send: 'evc.enableCollateral', args: [ctx.contracts.eVaults.eTST3.address], },
//     ]),
//     { action: 'checkpointTime' },

//     { action: 'jumpTime', time: 5, },
//     { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(9), ctx.wallet2.address], },
//     { action: 'jumpTime', time: 1, },
//     { from: ctx.wallet3, send: 'eVaults.eTST4.borrow', args: [et.units(9, 6), ctx.wallet3.address], },
//     { action: 'jumpTime', time: 1, },
//     { from: ctx.wallet4, send: 'eVaults.eWETH.borrow', args: [et.eth(9), ctx.wallet4.address], },
    
//     { action: 'jumpTime', time: 31*60 + 1, },
//     { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet2.address], },
//     { action: 'jumpTime', time: 5, },
//     { from: ctx.wallet3, send: 'eVaults.eTST4.borrow', args: [et.units(1, 6), ctx.wallet3.address], },
//     { action: 'jumpTime', time: 5, },
//     { from: ctx.wallet4, send: 'eVaults.eWETH.borrow', args: [et.eth(1), ctx.wallet4.address], },

//     { action: 'checkpointTime' },
// ];

// const basicSingleParams = (ctx, override = {}) => ({
//     underlyingIn: override.underlyingIn || ctx.contracts.tokens.TST.address,
//     underlyingOut: override.underlyingOut || ctx.contracts.tokens.WETH.address,
//     mode: override.mode || 0,
//     amountIn: override.amountIn || et.eth(1),
//     amountOut: override.amountOut || 0,
//     exactOutTolerance: override.exactOutTolerance || 0,
//     payload: et.abiEncode(['uint', 'uint'], [override.sqrtPriceLimitX96 || 0, et.DefaultUniswapFee])
// });

// et.testSet({
//     desc: 'swapHub - uni3 handler',
//     fixture: 'testing-real-uniswap-activated',
//     preActions: scenarios.swapUni3(),
// })


// .test({
//     desc: 'uni exact input single - basic',
//     actions: ctx => [
//         ...deposit(ctx, 'TST'),
//         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.eVaults.eWETH.address], assertEql: 0 },
//         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(100) },
//         { send: 'eVaults.eTST.approve', args: [ctx.contracts.swapHub.address, et.MaxUint256, ], },
//         { send: 'swapHub.swap', args: [ctx.wallet.address, ctx.wallet.address, ctx.contracts.eVaults.eTST.address, ctx.contracts.eVaults.eWETH.address,
//             ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx)]},
//         // euler underlying balances
//         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(99) },
//         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.eVaults.eWETH.address], onResult: async (balance) => {
//             let { output } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
//             et.expect(balance).to.equal(output);
//             ctx.stash.expectedOut = balance;
//         }, },
//         // total supply
//         { call: 'eVaults.eTST.totalSupply', equals: [et.eth(99), 0.01] },
//         { call: 'eVaults.eTST.totalAssets', equals: [et.eth(99), 0.01] },
//         { call: 'eVaults.eWETH.totalSupply', equals: () => [ctx.stash.expectedOut, '0.000000001'] },
//         { call: 'eVaults.eWETH.totalAssets', equals: () => [ctx.stash.expectedOut, '0.000000001'] },
//         // account balances 
//         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
//         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
//         { call: 'eVaults.eWETH.debtOf', args: [ctx.wallet.address], assertEql: 0 },
//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
//         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
//         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
//         // handler balances
//         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
//         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
//     ],
// })


// // .test({
// //     desc: 'uni exact input single - inverted',
// //     actions: ctx => [
// //         ...deposit(ctx, 'WETH'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, 
// //             basicSingleParams(ctx, {
// //                 underlyingIn: ctx.contracts.tokens.WETH.address,
// //                 underlyingOut: ctx.contracts.tokens.TST.address,
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(99) },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
// //             et.expect(balance).to.equal(output);
// //             ctx.stash.expectedOut = balance;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - max uint amount in',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: 0 },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(100) },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.MaxUint256,
// //             })
// //         ]},
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], equals: et.BN(et.DefaultReserve) },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.eth(100), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
// //             et.equals(balance, output, 0.001);
// //             ctx.stash.expectedOut = balance;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - retry approve for tokens requiring the allowance to be 0, like USDT',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'tokens.TST.configure', args: ['approve/require-zero-allowance', []], },

// //         // set non zero allowance on swap handler
// //         { send: 'tokens.TST.setAllowance', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, ctx.contracts.swapRouterV3.address, et.eth(1)]},

// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.MaxUint256,
// //             })
// //         ]},

// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], equals: et.BN(et.DefaultReserve) },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.eth(100), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
// //             et.equals(balance, output, 0.001);
// //             ctx.stash.expectedOut = balance;
// //         }},
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - outgoing decimals under 18',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST4', ctx.wallet, 0, 100, 6),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, {
// //             underlyingIn: ctx.contracts.tokens.TST4.address,
// //             underlyingOut: ctx.contracts.tokens.TST.address,
// //             amountIn: et.units(1, 6),
// //             amountOut: 0,
// //             mode: 0,
// //             exactOutTolerance: 0,
// //             payload: et.abiEncode(['uint', 'uint'], [0, et.DefaultUniswapFee]),
// //         }] },
// //         // euler underlying balances
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.units(99, 6) },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.units(1, 6), 'TST4/TST', et.eth(100), et.ratioToSqrtPriceX96(1e12, 1));
// //             // uni pool mint creates slightly different pool token balances when tokens are not inverted and init ratio is (1e12, 1) 
// //             // vs when tokens are inverted and ratio is (1, 1e12). This results in slightly different actual swap result vs calculated by sdk 
// //             et.equals(balance, output, 0.001);
// //             ctx.stash.expectedOut = balance;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eTST4.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], equals: [et.units(99, 6), 0.1] },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - incoming decimals under 18',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { action: 'cb', cb: async () => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/TST4', et.eth(100), et.ratioToSqrtPriceX96(1, 1e12));
// //             ctx.stash.expectedOut = output;
// //         }},
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, {
// //             underlyingIn: ctx.contracts.tokens.TST.address,
// //             underlyingOut: ctx.contracts.tokens.TST4.address,
// //             amountIn: et.eth(1),
// //             amountOut: 0,
// //             mode: 0,
// //             exactOutTolerance: 0,
// //             payload: et.abiEncode(['uint', 'uint'], [0, et.DefaultUniswapFee]),
// //         }], onLogs: logs => {
// //             et.expect(logs.length).to.equal(5);
// //             et.expect(logs[4].name).to.equal("VaultStatus");
// //             et.expect(logs[4].args.underlying).to.equal(ctx.contracts.tokens.TST4.address);
// //             et.equals(logs[4].args.totalBalances, et.eth(et.formatUnits(ctx.stash.expectedOut, 6)), 0.001);
// //             et.expect(logs[4].args.poolSize).to.equal(et.eth(et.formatUnits(ctx.stash.expectedOut, 6)));
// //         }},
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(99) },
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], assertEql: () => ctx.stash.expectedOut, },
// //         // account balances 
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.1 ] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(99), 0.1 ] },
// //         { call: 'eVaults.eTST4.balanceOf', args: [ctx.wallet.address], assertEql: () => ctx.stash.expectedOut.mul(et.units(1, 12)) },
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - between subaccounts',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST', ctx.wallet, 1),
// //         { send: 'swapHub.swap', args: [1, 2, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx), ] },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
// //             et.expect(balance).to.equal(output);
// //             ctx.stash.expectedOut = balance;
// //         }},
// //         { call: 'eVaults.eWETH.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 2)], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 2)], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.debtOf', args: [et.getSubAccount(ctx.wallet.address, 2)], assertEql: 0 },
// //         { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(99), 0.1 ] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(99), 0.1 ] },
// //         { call: 'eVaults.eTST.debtOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })



// // .test({
// //     desc: 'uni exact input single - interest rate updated',
// //     actions: ctx => [
// //         ...setupInterestRates(ctx),

// //         { action: 'jumpTime', time: 1, },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx)], },

// //         { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth('10.000004816784613841'), },
// //         { call: 'markets.interestRate', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.linearIRM('10.000004816784613841', '89'), },

// //         { call: 'eVaults.eWETH.totalBorrows', args: [], assertEql: et.eth('10.000004805630159981'), },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth('90.987158034397061298'), },
// //         { call: 'markets.interestRate', args: [ctx.contracts.eVaults.eWETH.address], assertEql: et.linearIRM('10.000004805630159981', '90.987158034397061298'), },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - max uint amount in with interest',
// //     actions: ctx => [
// //         ...setupInterestRates(ctx),
// //          { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },
// //         { action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmZero', },
// //         // make sure the pool can cover earned interest 
// //         ...deposit(ctx, 'TST', ctx.wallet3),
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerTSTBalance = r;
// //         } },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerWETHBalance = r;
// //         } },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountTSTBalance = r;
// //         } },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountWETHBalance = r;
// //         } },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, 
// //             basicSingleParams(ctx, { amountIn: et.MaxUint256, }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             et.assert(r.eq(ctx.stash.eulerTSTBalance.sub(ctx.stash.accountTSTBalance)));
// //         } },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(ctx.stash.accountTSTBalance, 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));
// //             et.expect(balance).to.equal(ctx.stash.eulerWETHBalance.add(output));
// //             ctx.stash.expectedOut = output;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             et.equals(r, ctx.stash.accountWETHBalance.add(ctx.stash.expectedOut), '0.00000000000000001'); // deposit rounded down
// //         }, },
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - max uint amount in with interest, outgoing decimals under 18',
// //     actions: ctx => [
// //         ...setupInterestRates(ctx),
// //         { action: 'setInterestRateModel', underlying: 'TST4', irm: 'irmZero', },
// //         { action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmZero', },
// //         // make sure the pool can cover earned interest 
// //         ...deposit(ctx, 'TST4', ctx.wallet3),
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerTST4Balance = r;
// //         } },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerWETHBalance = r;
// //         } },
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountTST4Balance = r;
// //         } },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountWETHBalance = r;
// //         } },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, 
// //             basicSingleParams(ctx, {
// //                 underlyingIn: ctx.contracts.tokens.TST4.address,
// //                 underlyingOut: ctx.contracts.tokens.WETH.address,
// //                 amountIn: et.MaxUint256,
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             et.assert(r.eq(ctx.stash.eulerTST4Balance.sub(ctx.stash.accountTST4Balance)));
// //         } },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(ctx.stash.accountTST4Balance, 'TST4/WETH', et.eth(100), et.ratioToSqrtPriceX96(1e12, 1));
// //             et.equals(balance, ctx.stash.eulerWETHBalance.add(output), '0.00000000000001'); // price is not exactly 1 after mint
// //             ctx.stash.expectedOut = output;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             et.equals(r, ctx.stash.accountWETHBalance.add(ctx.stash.expectedOut), '0.00000000000001');
// //         }, },
// //         { call: 'eVaults.eTST4.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - max uint amount in with interest, incoming decimals under 18',
// //     actions: ctx => [
// //         ...setupInterestRates(ctx),
// //         { action: 'setInterestRateModel', underlying: 'TST4', irm: 'irmZero', },
// //         { action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmZero', },
// //         // make sure the pool can cover earned interest 
// //         ...deposit(ctx, 'WETH', ctx.wallet3),
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerTST4Balance = r;
// //         } },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             ctx.stash.eulerWETHBalance = r;
// //         } },
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountTST4Balance = r;
// //         } },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             ctx.stash.accountWETHBalance = r;
// //         } },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 underlyingIn: ctx.contracts.tokens.WETH.address,
// //                 underlyingOut: ctx.contracts.tokens.TST4.address,
// //                 amountIn: et.MaxUint256,
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
// //             et.assert(r.eq(ctx.stash.eulerWETHBalance.sub(ctx.stash.accountWETHBalance)));
// //         } },
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { output } = await ctx.getUniswapInOutAmounts(ctx.stash.accountWETHBalance, 'TST4/WETH', et.eth(100), et.ratioToSqrtPriceX96(1e12, 1), true);

// //             et.equals(balance, ctx.stash.eulerTST4Balance.add(output), '0.00000000000001'); // price is not exactly 1 after mint
// //             ctx.stash.expectedOut = output;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eTST4.maxWithdraw', args: [ctx.wallet.address], onResult: r => {
// //             et.equals(r, ctx.stash.accountTST4Balance.add(ctx.stash.expectedOut));
// //         }, },
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST4.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - deflationary token out',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'tokens.WETH.configure', args: ['transfer/deflationary', et.abiEncode(['uint256'], [et.eth(0.1)])], },

// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx)]},
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(99) },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             ctx.stash.expectedOut = balance;
// //         }, },
// //         // total supply
// //         { call: 'eVaults.eTST.totalSupply', equals: [et.eth(99), 0.01] },
// //         { call: 'eVaults.eTST.totalAssets', equals: [et.eth(99), 0.01] },
// //         { call: 'eVaults.eWETH.totalSupply', equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.totalAssets', equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         // account balances 
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedOut, '0.000000001'] },
// //         { call: 'eVaults.eWETH.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(99), 0.1] },
// //         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })

// // .test({
// //     desc: 'uni exact input single - min amount out not reached',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, 
// //             basicSingleParams(ctx, {
// //                 amountOut: et.eth(2),
// //             }),
// //         ], expectError: 'Too little received' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - above price limit',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, 
// //             basicSingleParams(ctx, {
// //                 sqrtPriceLimitX96: ctx.poolAdjustedRatioToSqrtPriceX96('TST/WETH', 2, 1),
// //             }),
// //         ], expectError: 'SPL' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - insufficient pool size',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.eth(101),
// //             })
// //         ], expectError: 'e/swap-hub/insufficient-pool-size' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - insufficient balance',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         ...deposit(ctx, 'TST', ctx.wallet2),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.eth(101),
// //             }),
// //         ], expectError: 'E_InsufficientBalance' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - market not activated - in',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 underlyingIn: ctx.contracts.tokens.UTST.address,
// //             }),
// //         ], expectError: 'e/swap-hub/in-market-not-activated' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - market not activated - out',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 underlyingOut: ctx.contracts.tokens.UTST.address,
// //             }),
// //         ], expectError: 'e/swap-hub/out-market-not-activated' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - deflationary token in',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'tokens.TST.configure', args: ['transfer/deflationary', et.abiEncode(['uint256'], [et.eth(1)])], },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx), ],
// //             expectError: 'STF'
// //         },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - invalid mode',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, basicSingleParams(ctx, { mode: 2 }), ],
// //             expectError: 'SwapHandlerUniswapV3: invalid mode'
// //         },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input single - collateral violation',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         ...deposit(ctx, 'TST2', ctx.wallet2),
// //         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address] },
// //         { send: 'eVaults.eTST2.borrow', args: [et.eth(20), ctx.wallet.address] },

// //         // liquidity check should fail
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.eth(50),
// //             }),
// //         ], expectError: 'RM_AccountLiquidity' },

// //         // unless the incoming token counts as collateral as well
// //         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eWETH.address] },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 amountIn: et.eth(50),
// //             }),
// //         ] },
// //     ],
// // })



// // .test({
// //     desc: 'uni exact input single - leverage in a batch',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST', ctx.wallet, 0, 1),
// //         ...deposit(ctx, 'TST', ctx.wallet2, 0, 1000),
// //         ...deposit(ctx, 'WETH', ctx.wallet2, 0, 1000),
// //         { action: 'setMarketConfigRMC', tok: 'WETH', config: { borrowFactor: 1}, },

// //         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address] },
// //         { action: 'sendBatch', batch: [
// //             { send: 'eVaults.eWETH.wind', args: [et.eth(2.5)] },
// //             { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //                 basicSingleParams(ctx, {
// //                     underlyingIn: ctx.contracts.tokens.WETH.address,
// //                     underlyingOut: ctx.contracts.tokens.TST.address,
// //                     amountIn: et.eth(2.5)
// //                 }),
// //             ]}, 
// //         ]}, 
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth('3.431885259897065638'), 0.001] },
// //         { call: 'eVaults.eWETH.debtOf', args: [ctx.wallet.address], assertEql: et.eth(2.5) },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input multi-hop - basic',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, async () => ({
// //             underlyingIn: ctx.contracts.tokens.TST.address,
// //             underlyingOut: ctx.contracts.tokens.TST3.address,
// //             amountIn: et.eth(1),
// //             amountOut: 0,
// //             mode: 0,
// //             exactOutTolerance: 0,
// //             payload: await ctx.encodeUniswapPath(['TST/WETH', 'TST2/WETH', 'TST2/TST3'], 'TST', 'TST3'),
// //         })], onLogs: logs => {
// //             logs = logs.filter(l => l.address === ctx.contracts.euler.address);
// //             et.expect(logs.length).to.equal(5);
// //             et.expect(logs[0].name).to.equal('RequestSwapHub');
// //             et.expect(logs[0].args.accountIn.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.accountOut.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.underlyingIn).to.equal(ctx.contracts.tokens.TST.address);
// //             et.expect(logs[0].args.underlyingOut).to.equal(ctx.contracts.tokens.TST3.address);
// //             et.expect(logs[0].args.amountIn).to.equal(et.eth(1));
// //             et.expect(logs[0].args.amountOut).to.equal(0);
// //             et.expect(logs[0].args.mode).to.equal(0);
// //             et.expect(logs[0].args.swapHandler).to.equal(ctx.contracts.swapHandlers.swapHandlerUniswapV3.address);
// //         }},
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(99) },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth('0.962329947778299007')},
// //         { call: 'tokens.TST2.balanceOf', args: [ctx.contracts.euler.address], assertEql: 0},
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: 0},
// //         // account balances 
// //         { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet.address], equals: [et.eth('0.962329947778299007'), '000000001'] },
// //         { call: 'eVaults.eTST3.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth('0.962329947778299007'), '000000001'] },
// //         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], assertEql: 0 },

// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(99), 0.01] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(99), 0.01] },
// //         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
        
// //         { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST2.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },

// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact input multi-hop - out token same as in token',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST2'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, async () => ({
// //             underlyingIn: ctx.contracts.tokens.TST2.address,
// //             underlyingOut: ctx.contracts.tokens.TST2.address,
// //             amountIn: et.eth(1),
// //             amountOut: 0,
// //             mode: 0,
// //             exactOutTolerance: 0,
// //             payload: await ctx.encodeUniswapPath(['TST2/WETH', 'TST3/WETH', 'TST2/TST3'], 'TST2', 'TST2'),
// //         })], expectError: 'e/swap-hub/same' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - basic',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //             }),
// //         ], onLogs: logs => {
// //             logs = logs.filter(l => l.address === ctx.contracts.euler.address);
// //             et.expect(logs.length).to.equal(5);
// //             et.expect(logs[0].name).to.equal('RequestSwapHub');
// //             et.expect(logs[0].args.accountIn.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.accountOut.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.underlyingIn).to.equal(ctx.contracts.tokens.TST.address);
// //             et.expect(logs[0].args.underlyingOut).to.equal(ctx.contracts.tokens.WETH.address);
// //             et.expect(logs[0].args.amountIn).to.equal(et.MaxUint256);
// //             et.expect(logs[0].args.amountOut).to.equal(et.eth(1));
// //             et.expect(logs[0].args.mode).to.equal(1);
// //             et.expect(logs[0].args.swapHandler).to.equal(ctx.contracts.swapHandlers.swapHandlerUniswapV3.address);
// //         }},
// //         // euler underlying balances
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(1) },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { input } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));

// //             et.equals(balance, et.eth(100).sub(input), '0.000000001');
// //             ctx.stash.expectedIn = balance;
// //         }},
// //         // total supply
// //         { call: 'eVaults.eTST.totalSupply', equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.totalAssets', equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eWETH.totalSupply', equals: [et.eth(1), '0.000000001'] },
// //         { call: 'eVaults.eWETH.totalAssets', equals: [et.eth(1), '0.000000001'] },
// //         // account balances 
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },
// //         { call: 'eVaults.eWETH.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - out amount tolerance for deflationary tokens',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'tokens.WETH.configure', args: ['transfer/deflationary', et.abiEncode(['uint256'], [et.eth(0.1)])], },

// //         // deflationary token reverts without tolerance
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //                 exactOutTolerance: 0,
// //             }),
// //         ], expectError: 'e/swap-hub/insufficient-output', },

// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //                 exactOutTolerance: et.eth(0.1),
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(1 - 0.1) },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             let { input } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1));

// //             et.equals(balance, et.eth(100).sub(input), '0.000000001');
// //             ctx.stash.expectedIn = balance;
// //         }},
// //         // total supply
// //         { call: 'eVaults.eTST.totalSupply', equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.totalAssets', equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eWETH.totalSupply', equals: [et.eth(1 - 0.1), '0.000000001'] },
// //         { call: 'eVaults.eWETH.totalAssets', equals: [et.eth(1 - 0.1), '0.000000001'] },
// //         // account balances 
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1 - 0.1), 0.01] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1 - 0.1), 0.01] },
// //         { call: 'eVaults.eWETH.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - amount in max larger than pool size',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         ...deposit(ctx, 'TST2', ctx.wallet2),
// //         { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.contracts.eVaults.eTST2.address], },
// //         { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(10), ctx.wallet2.address], },

// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], equals: [et.eth('90'), 0.0001], },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth('100'), 0.0001] },

// //         // amount in max will use the whole balance, which is larger than the pool size
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //             }),
// //         ], expectError: 'e/swap-hub/insufficient-pool-size' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - interest rate updated',
// //     actions: ctx => [
// //         ...setupInterestRates(ctx),

// //         { action: 'jumpTime', time: 1, },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.eth(90),
// //                 amountOut: et.eth(1),
// //             }),
// //         ], },

// //         { call: 'eVaults.eTST.totalBorrows', args: [], assertEql: et.eth('10.000004816784613841'), },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth('88.986859568604804310'), },
// //         { call: 'markets.interestRate', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.linearIRM('10.000004816784613841', '88.986859568604804310'), },

// //         { call: 'eVaults.eWETH.totalBorrows', args: [], assertEql: et.eth('10.000004805630159981'), },
// //         { call: 'markets.interestRate', args: [ctx.contracts.eVaults.eWETH.address], assertEql: et.linearIRM('10.000004805630159981', '91'), },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - max amount in not sufficient',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.eth(1),
// //                 amountOut: et.eth(1),
// //             }),
// //         ], expectError: 'STF' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - tolerance larger than amount out',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //                 exactOutTolerance: et.eth(2),
// //             }),
// //         ], expectError: 'e/swap-hub/exact-out-tolerance' },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output single - exact amount in max',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         async () => {
// //             let { input } = await ctx.getUniswapInOutAmounts(et.eth(1), 'TST/WETH', et.eth(100), et.ratioToSqrtPriceX96(1, 1))
// //             ctx.stash.amountInMax = input;
// //         },
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             () => basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: ctx.stash.amountInMax,
// //                 amountOut: et.eth(1),
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], equals: [et.eth(1), 0.01] },
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], onResult: async (balance) => {
// //             et.expect(balance).to.equal(et.eth(100).sub(ctx.stash.amountInMax));
// //             ctx.stash.expectedIn = balance;
// //         }},
// //         // account balances 
// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },

// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: () => [ctx.stash.expectedIn, '0.000000001'] },

// //         { call: 'tokens.TST.allowance', args: [ctx.contracts.euler.address, ctx.contracts.swapRouterV3.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output multi-hop - basic',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             async () => ({
// //                 underlyingIn: ctx.contracts.tokens.TST.address,
// //                 underlyingOut: ctx.contracts.tokens.TST3.address,
// //                 amountIn: et.MaxUint256,
// //                 amountOut: et.eth(1),
// //                 mode: 1,
// //                 exactOutTolerance: 0,
// //                 payload: await ctx.encodeUniswapPath(['TST/WETH', 'TST2/WETH', 'TST2/TST3'], 'TST', 'TST3', true),
// //             }),
// //         ], onLogs: logs => {
// //             logs = logs.filter(l => l.address === ctx.contracts.euler.address);
// //             et.expect(logs.length).to.equal(5);
// //             et.expect(logs[0].name).to.equal('RequestSwapHub');
// //             et.expect(logs[0].args.accountIn.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.accountOut.toLowerCase()).to.equal(et.getSubAccount(ctx.wallet.address, 0));
// //             et.expect(logs[0].args.underlyingIn).to.equal(ctx.contracts.tokens.TST.address);
// //             et.expect(logs[0].args.underlyingOut).to.equal(ctx.contracts.tokens.TST3.address);
// //             et.expect(logs[0].args.amountIn).to.equal(et.MaxUint256);
// //             et.expect(logs[0].args.amountOut).to.equal(et.eth(1));
// //             et.expect(logs[0].args.mode).to.equal(1);
// //             et.expect(logs[0].args.swapHandler).to.equal(ctx.contracts.swapHandlers.swapHandlerUniswapV3.address);
// //         }},
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth('98.959640948996359994') },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(1)},
// //         { call: 'tokens.TST2.balanceOf', args: [ctx.contracts.euler.address], assertEql: 0},
// //         { call: 'tokens.WETH.balanceOf', args: [ctx.contracts.euler.address], assertEql: 0},
// //         // account balances 
// //         { call: 'eVaults.eTST3.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },
// //         { call: 'eVaults.eTST3.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1), 0.01] },
// //         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], assertEql: 0 },

// //         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth('98.959640948996359994'), '0.000000001'] },
// //         { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth('98.959640948996359994'), '0.000000001'] },
// //         { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 0 },
        
// //         { call: 'eVaults.eTST2.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eTST2.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },

// //         { call: 'eVaults.eWETH.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
// //         { call: 'eVaults.eWETH.maxWithdraw', args: [ctx.wallet.address], assertEql: 0 },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'uni exact output multi-hop - exact amount in max',
// //     actions: ctx => [
// //         ...deposit(ctx, 'TST'),
// //         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniswapV3.address,
// //             async () => ({
// //                 underlyingIn: ctx.contracts.tokens.TST.address,
// //                 underlyingOut: ctx.contracts.tokens.TST3.address,
// //                 amountIn: et.eth(100).sub(et.eth('98.959640948996359994')),
// //                 amountOut: et.eth(1),
// //                 mode: 1,
// //                 exactOutTolerance: 0,
// //                 payload: await ctx.encodeUniswapPath(['TST/WETH', 'TST2/WETH', 'TST2/TST3'], 'TST', 'TST3', true),
// //             }),
// //         ] },
// //         // euler underlying balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth('98.959640948996359994') },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.euler.address], assertEql: et.eth(1)},
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })


// // .test({
// //     desc: 'recover tokens',
// //     actions: ctx => [
// //         { send: 'tokens.TST.mint', args: [ctx.wallet.address, et.eth(10)], },
// //         { send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], },
// //         { send: 'tokens.TST.transfer', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address, et.eth(2)]},
// //         { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(8) },

// //         { send: 'swapHandlers.swapHandlerUniswapV3.executeSwap', args: [
// //             basicSingleParams(ctx, {
// //                 mode: 1,
// //                 amountIn: 0,
// //                 amountOut: 1,
// //             }),
// //         ], },

// //         { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(10), 0.00001] },
// //         // handler balances
// //         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //         { call: 'tokens.TST3.balanceOf', args: [ctx.contracts.swapHandlers.swapHandlerUniswapV3.address], assertEql: 0 },
// //     ],
// // })



// .run();

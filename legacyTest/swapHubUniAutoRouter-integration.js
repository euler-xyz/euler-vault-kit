const et = require('./lib/eTestLib');
const testSwaps = require('./lib/uniswap-payloads.json');
const getPayload = (swap, receiver) =>
    testSwaps[swap].payload.replace(/\{receiverAddress\}/g, receiver.slice(2));

const forkAtBlock = swap => testSwaps[swap].forkAtBlock;

const borrowSetup = ctx => ([
    { action: 'setTokenBalanceInStorage', token: 'BAT', for: ctx.wallet2.address, amount: 100_000 },
    { from: ctx.wallet2, send: 'tokens.BAT.approve', args: [ctx.contracts.euler.address, et.MaxUint256], },
    { from: ctx.wallet2, send: 'eVaults.eBAT.deposit', args: [et.MaxUint256], },

    { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet2.address, amount: 100_000 },
    { from: ctx.wallet2, send: 'tokens.USDC.approve', args: [ctx.contracts.eVaults.eUSDCaddress, et.MaxUint256], },
    { from: ctx.wallet2, send: 'eVaults.eUSDC.deposit', args: [et.MaxUint256], },

    { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eGRT.address], },
    { action: 'setMarketConfigRMC', tok: 'GRT', config: { collateralFactor: .9}, },
    { action: 'setMarketConfigRMC', tok: 'BAT', config: { borrowFactor: .5}, },
    { action: 'setMarketConfigRMC', tok: 'USDC', config: { borrowFactor: .5}, },
]);

const encodeExactOutputPayload = (primary, path) => et.abiEncode(['bytes', 'bytes'], [primary, path]);

// et.testSet({
//     desc: 'swapHub - uniswap auto router handler',
//     fixture: 'mainnet-fork',
//     timeout: 200_000,
//     preActions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'DAI', for: ctx.wallet.address, amount: 100_000 },
//         { send: 'tokens.DAI.approve', args: [ctx.contracts.euler.address, et.MaxUint256], },
//         { send: 'eVaults.eDAI.deposit', args: [et.MaxUint256], },

//         { action: 'setTokenBalanceInStorage', token: 'GRT', for: ctx.wallet.address, amount: 1_000_000 },
//         { send: 'tokens.GRT.approve', args: [ctx.contracts.euler.address, et.MaxUint256], },
//         { send: 'eVaults.eGRT.deposit', args: [et.MaxUint256], },
//     ],
// })


// .test({
//     desc: 'basic exact input swap, DAI - RGT',
//     forkAtBlock: forkAtBlock('DAI-RGT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.RGT.address,
//             amountIn: et.eth(5_000),
//             amountOut: 0,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('DAI-RGT', ctx.contracts.euler.address),
//         }]},
//         //// total supply
//         { call: 'eVaults.eDAI.totalSupply', equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eDAI.totalAssets', equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eRGT.totalSupply', equals: [et.eth('627.099209553061407856'), 0.000001] },
//         { call: 'eVaults.eRGT.totalAssets', equals: [et.eth('627.099209553061407856'), 0.000001] },
//         //// account balances 
//         { call: 'eVaults.eDAI.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eRGT.balanceOf', args: [ctx.wallet.address], equals: [et.eth('627.099209553061407856'), 0.000001] },
//         { call: 'eVaults.eRGT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth('627.099209553061407856'), 0.000001]},
//     ],
// })


// .test({
//     desc: 'basic exact input swap, DAI - RGT, minimum amount not reached',
//     forkAtBlock: forkAtBlock('DAI-RGT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.RGT.address,
//             amountIn: et.eth(5_000),
//             amountOut: et.eth('628.1'),
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('DAI-RGT', ctx.contracts.euler.address),
//         }], expectError: 'e/swap-hub/insufficient-output'},
//     ],
// })


// .test({
//     desc: 'exact input swap between subaccounts',
//     forkAtBlock: forkAtBlock('DAI-RGT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.RGT.address,
//             amountIn: et.eth(5_000),
//             amountOut: 0,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('DAI-RGT', ctx.contracts.euler.address),
//         }]},
//         // total supply
//         { call: 'eVaults.eDAI.totalSupply', equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eDAI.totalAssets', equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eRGT.totalSupply', equals: [et.eth('627.099209553061407856'), 0.000001] },
//         { call: 'eVaults.eRGT.totalAssets', equals: [et.eth('627.099209553061407856'), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eDAI.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 0)],equals: [et.eth(100_000).sub(et.eth(5_000)), 0.000001] },
//         { call: 'eVaults.eRGT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth('627.099209553061407856'), 0.000001] },
//         { call: 'eVaults.eRGT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth('627.099209553061407856'), 0.000001]},
//     ],
// })


// .test({
//     desc: 'basic exact output swap, DAI - BAT',
//     forkAtBlock: forkAtBlock('DAI-BAT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: et.eth(200_000),
//             amountIn: et.eth(100_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('DAI-BAT', ctx.contracts.euler.address), '0x'),
//         }]},
//         // total supply
//         { call: 'eVaults.eDAI.totalSupply', equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eDAI.totalAssets', equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eBAT.totalSupply', equals: [et.eth(200_000), 0.000001] },
//         { call: 'eVaults.eBAT.totalAssets', equals: [et.eth(200_000), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eDAI.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eBAT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(200_000), 0.000001] },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(200_000), 0.000001] },
//     ],
// })


// .test({
//     desc: 'basic exact output swap, DAI - BAT, maximum amount exceeded',
//     forkAtBlock: forkAtBlock('DAI-BAT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: et.eth(200_000),
//             amountIn: et.eth('78444.32'),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('DAI-BAT', ctx.contracts.euler.address), '0x'),
//         }], expectError: 'STF'}, // safe transfer from error due to too little allowance granted to uniswap router
//     ],
// })


// .test({
//     desc: 'exact output swap between subaccounts',
//     forkAtBlock: forkAtBlock('DAI-BAT'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: et.eth(200_000),
//             amountIn: et.eth(100_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('DAI-BAT', ctx.contracts.euler.address), '0x'),
//         }]},
//         // total supply
//         { call: 'eVaults.eDAI.totalSupply', equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001], },
//         { call: 'eVaults.eDAI.totalAssets', equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001], },
//         { call: 'eVaults.eBAT.totalSupply', equals: [et.eth(200_000), 0.000001] },
//         { call: 'eVaults.eBAT.totalAssets', equals: [et.eth(200_000), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eDAI.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: [et.eth(100_000).sub(et.eth('78444.327668064491635904')), 0.000001] },
//         { call: 'eVaults.eBAT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(200_000), 0.000001] },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(200_000), 0.000001]},
//     ],
// })


// .test({
//     desc: 'basic swap and repay, GRT - BAT, secondary path not provided',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), '0x'),
//         }, et.eth(1_000)
//         ], expectError: 'SwapHandlerPayloadBase: secondary path format'},
//     ],
// })


// .test({
//     desc: 'basic swap and repay, GRT - BAT, secondary path too short',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), '0x1234'),
//         }, et.eth(1_000)
//         ], expectError: 'SwapHandlerPayloadBase: secondary path format'},
//     ],
// })


// .test({
//     desc: 'basic swap and repay, GRT - BAT, secondary path too long',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), '0x' + '11'.repeat(20 + (20 * 23) + 1)),
//         }, et.eth(1_000)
//         ], expectError: 'SwapHandlerPayloadBase: secondary path format'},
//     ],
// })


// .test({
//     desc: 'basic swap and repay, GRT - BAT, maximum amount exceeded',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth('5476.69'),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), testSwaps['GRT-BAT'].path),
//         }, et.eth(1_000)
//         ], expectError: 'STF'}, // safe transfer from error due to too tokens provided to the handler
//     ],
// })


// .test({
//     desc: 'swap and repay with outstanding debt, path v2, GRT - BAT',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), testSwaps['GRT-BAT'].path)
//         }, et.eth(1_000), // repay 2/3 of the borrowed amount
//         ]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 1], },
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 1], },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 1], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 1], },
//         { call: 'eVaults.eBAT.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [ctx.wallet.address], equals: 0},
//         { call: 'eVaults.eBAT.debtOf', args: [ctx.wallet.address], equals: [et.eth(1_000)] },
//     ],
// })


// .test({
//     desc: 'swap and repay full debt with secondary swap, path v2, GRT - BAT',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         () => {
//             ctx.stash.secondaryAmountIn = et.eth('2775.905768620480495051')
//         },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), testSwaps['GRT-BAT'].path)
//         }, 0,
//         ]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: () => [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')).sub(ctx.stash.secondaryAmountIn), 1], },
//         { call: 'eVaults.eGRT.totalAssets', equals: () => [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')).sub(ctx.stash.secondaryAmountIn), 1], },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: () => [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')).sub(ctx.stash.secondaryAmountIn), 1], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: () => [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')).sub(ctx.stash.secondaryAmountIn), 1], },
//         { call: 'eVaults.eBAT.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [ctx.wallet.address], equals: 0},

//         { call: 'eVaults.eBAT.debtOf', args: [ctx.wallet.address], equals: 0 },
//     ],
// })


// .test({
//     desc: 'swap and repay between subaccounts, outstanding debt',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),

//         { send: 'eVaults.eGRT.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(500_000)], },
//         { send: 'evc.enableCollateral', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eGRT.address], },
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },

//         { send: 'swapHub.swapAndRepay', args: [0, 1, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0, // ignored
//             amountIn: et.eth(1_000_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), testSwaps['GRT-BAT'].path),
//         }, et.eth(1_000)
//         ]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 100] }, // high error tolerance to cover for accrued interest repay
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(1_000_000).sub(et.eth('5476.695110214614125399')), 100] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: [et.eth(500_000).sub(et.eth('5476.695110214614125399')), 100]},
//         { call: 'eVaults.eGRT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: [et.eth(500_000).sub(et.eth('5476.695110214614125399')), 100]},
//         { call: 'eVaults.eGRT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(500_000), 0.000001] },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth(500_000), 0.000001] },

//         { call: 'eVaults.eBAT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: 0 },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 0)], equals: 0},
//         { call: 'eVaults.eBAT.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: 0 },
//         { call: 'eVaults.eBAT.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: 0},
//         { call: 'eVaults.eBAT.debtOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: et.eth(1_000) },
//     ],
// })



// .test({
//     desc: 'basic swap and repay with outstanding debt, path v2, GRT - BAT, maximum amount exceeded',
//     forkAtBlock: forkAtBlock('GRT-BAT'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eBAT.borrow', args: [et.eth(3_000), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.BAT.address,
//             amountOut: 0,
//             amountIn: et.eth('5476.69'),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-BAT', ctx.contracts.euler.address), testSwaps['GRT-BAT'].path),
//         }, et.eth(1_000), // repay 2/3 of the borrowed amount
//         ], expectError: 'STF'}, // safe transfer from error due to too little tokens sent to the handler
//     ],
// })


// .test({
//     desc: 'basic exact input swap, GRT - USDC',
//     forkAtBlock: forkAtBlock('GRT-USDC'),
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth(1_234),
//             amountOut: 0,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(1_000_000).sub(et.eth(1_234)), 0.000001] },
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(1_000_000).sub(et.eth(1_234)), 0.000001] },
//         { call: 'eVaults.eUSDC.totalSupply', equals: [et.eth('173.902589'), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals:  [et.units('173.902589', 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(1_000_000).sub(et.eth(1_234)), 0.000001] },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1_000_000).sub(et.eth(1_234)), 0.000001] },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: [et.eth('173.902589'), 0.000001] },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: [et.units('173.902589', 6), 0.000001] },
//     ],
// })


// .test({
//     desc: 'swap and repay full debt with secondary exact swap, path v3, DAI - USDC',
//     forkAtBlock: forkAtBlock('DAI-USDC'),
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eUSDC.borrow', args: [et.units(10_000, 6), ctx.wallet.address], },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandlerUniAutoRouter.address, {
//             underlyingIn: ctx.contracts.tokens.DAI.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountOut: 0,
//             amountIn: et.eth(100_000),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('DAI-USDC', ctx.contracts.euler.address), testSwaps['DAI-USDC'].path),
//         }, 0, // repay debt in full
//         ]},
//         // total supply
//         { call: 'eVaults.eDAI.totalSupply', equals: [et.eth(100_000).sub(et.eth('10000.680069720097554327')), 1], },
//         { call: 'eVaults.eDAI.totalAssets', equals: [et.eth(100_000).sub(et.eth('10000.680069720097554327')), 1], },
//         // account balances 
//         { call: 'eVaults.eDAI.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('10000.680069720097554327')), 1], },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('10000.680069720097554327')), 1], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: 0},
//         { call: 'eVaults.eUSDC.debtOf', args: [ctx.wallet.address], equals: 0 },
//     ],
// })


// .run();
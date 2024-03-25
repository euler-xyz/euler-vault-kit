const et = require('./lib/eTestLib');
const testSwaps = require('./lib/1inch-swaphub-payloads.json');

const getPayload = (swap, receiver) =>
    testSwaps[swap].payload.replace(/\{receiverAddress\}/g, receiver.slice(2));

const forkAtBlock = swap => testSwaps[swap].forkAtBlock;
const encodeExactOutputPayload = (primary, path) => et.abiEncode(['bytes', 'bytes'], [primary, path]);

const borrowSetup = ctx => ([
    { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet2.address, amount: 100_000 },
    { from: ctx.wallet2, send: 'tokens.USDC.approve', args: [ctx.contracts.eVaults.eUSDCaddress, et.MaxUint256], },
    { from: ctx.wallet2, send: 'eVaults.eUSDC.deposit', args: [et.MaxUint256], },

    { action: 'setTokenBalanceInStorage', token: 'STETH', for: ctx.wallet2.address, amount: 100_000, slot: 0 },
    { from: ctx.wallet2, send: 'tokens.STETH.approve', args: [ctx.contracts.euler.address, et.MaxUint256], },
    { from: ctx.wallet2, send: 'eVaults.eSTETH.deposit', args: [et.MaxUint256], },

    { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eGRT.address], },
]);


// et.testSet({
//     desc: 'swapHub - 1inch handler',
//     fixture: 'mainnet-fork',
//     timeout: 200_000,
//     forkAtBlock: forkAtBlock('GRT-USDC'),
//     preActions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'GRT', for: ctx.wallet.address, amount: 100_000 },
//         { send: 'tokens.GRT.approve', args: [ctx.contracts.euler.address, et.MaxUint256], },
//         { send: 'eVaults.eGRT.deposit', args: [et.MaxUint256], },
//     ],
// })


// .test({
//     desc: 'basic swap, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1000'),
//             amountOut: 1,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001]},
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.totalSupply', equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals: [et.units('125.018572', 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: [et.units('125.018572', 6), 0.000001]},
//         // handler balances
//         { call: 'tokens.GRT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.USDC.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'exact output swap, GRT - USDC, received more than requested',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.MaxUint256,
//             amountOut: et.units('120', 6),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV2)
//         }]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001]},
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.totalSupply', equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals: [et.units('125.018572', 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: [et.units('125.018572', 6), 0.000001]},
//         // handler balances
//         { call: 'tokens.GRT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.USDC.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'swap between subaccounts, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1000'),
//             amountOut: 1,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001]},
//         { call: 'eVaults.eGRT.totalAssets', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.totalSupply', equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals: [et.units('125.018572', 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.eth('125.018572'), 0.000001] },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: [et.units('125.018572', 6), 0.000001]},
//         // handler balances
//         { call: 'tokens.GRT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.USDC.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'Insufficient amount in for primary, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('900'),
//             amountOut: 1,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }], expectError: 'ERC20: transfer amount exceeds balance'},
//     ],
// })


// .test({
//     desc: 'Insufficient amount in for secondary, GRT - USDC, secondary V2',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1010'),
//             amountOut: et.units('200', 6),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV2)
//         }], expectError: 'TransferHelper: TRANSFER_FROM_FAILED'},
//     ],
// })


// .test({
//     desc: 'Insufficient amount in for secondary, GRT - USDC, secondary V3',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 1, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1010'),
//             amountOut: et.units('200', 6),
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV3)
//         }], expectError: 'STF'},
//     ],
// })


// .test({
//     desc: 'Insufficient output, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1000'),
//             amountOut: et.units('130', 6),
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }], expectError: 'e/swap-hub/insufficient-output'},
//     ],
// })


// .test({
//     desc: 'Receiver mismatch, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1000'),
//             amountOut: 1,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.wallet.address),
//         }], expectError: 'e/swap-hub/insufficient-output'},
//     ],
// })


// .test({
//     desc: 'Invalid mode, GRT - USDC',
//     actions: ctx => [
//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.eth('1000'),
//             amountOut: 1,
//             mode: 2,
//             exactOutTolerance: 0,
//             payload: getPayload('GRT-USDC', ctx.contracts.euler.address),
//         }], expectError: 'SwapHandlerCombinedBase: invalid mode'},
//     ],
// })


// .test({
//     desc: 'basic swap and repay, full debt, GRT - USDC, secondary V2',
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eUSDC.borrow', args: [et.units(130, 6), ctx.wallet.address] },
//         () => {
//             ctx.stash.secondaryAmountIn = et.eth('39.892390152140367681');
//         },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.MaxUint256,
//             amountOut: 0,
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV2)
//         }, 0]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001]},
//         { call: 'eVaults.eGRT.totalAssets', equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eUSDC.totalSupply', equals: () => [et.eth(100_000), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals: () => [et.units(100_000, 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: 0},
//         { call: 'eVaults.eUSDC.debtOf', args: [ctx.wallet.address], equals: 0 },
//         // handler balances
//         { call: 'tokens.GRT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.USDC.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'basic swap and repay, full debt, GRT - USDC, secondary V3',
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eUSDC.borrow', args: [et.units(130, 6), ctx.wallet.address] },
//         () => {
//             ctx.stash.secondaryAmountIn = et.eth('40.558961567114676716');
//         },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.MaxUint256,
//             amountOut: 0,
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV3)
//         }, 0]},
//         // total supply
//         { call: 'eVaults.eGRT.totalSupply', equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001]},
//         { call: 'eVaults.eGRT.totalAssets', equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eUSDC.totalSupply', equals: () => [et.eth(100_000), 0.000001] },
//         { call: 'eVaults.eUSDC.totalAssets', equals: () => [et.units(100_000, 6), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eGRT.balanceOf', args: [ctx.wallet.address], equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.000001], },
//         { call: 'eVaults.eUSDC.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: 0},
//         { call: 'eVaults.eUSDC.debtOf', args: [ctx.wallet.address], equals: 0 },
//         // handler balances
//         { call: 'tokens.GRT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.USDC.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'swap and repay, GRT - USDC, primary swap more than debt',
//     actions: ctx => [
//         ...borrowSetup(ctx),
//         { send: 'eVaults.eUSDC.borrow', args: [et.units(90, 6), ctx.wallet.address] },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.GRT.address,
//             underlyingOut: ctx.contracts.tokens.USDC.address,
//             amountIn: et.MaxUint256,
//             amountOut: 0,
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('GRT-USDC', ctx.contracts.euler.address), testSwaps['GRT-USDC'].pathV2)
//         }, 0], expectError: 'E_RepayTooMuch'},
//      ],
// })


// .test({
//     desc: 'basic swap, USDT - STETH',
//     forkAtBlock: forkAtBlock('USDT-STETH'),
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDT', for: ctx.wallet.address, amount: 100_000 },
//         { send: 'tokens.USDT.approve', args: [ctx.contracts.eVaults.eUSDT.address, et.MaxUint256], },
//         { send: 'eVaults.eUSDT.deposit', args: [et.MaxUint256], },

//         { send: 'swapHub.swap', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.USDT.address,
//             underlyingOut: ctx.contracts.tokens.STETH.address,
//             amountIn: et.units('1000',  6),
//             amountOut: 1,
//             mode: 0,
//             exactOutTolerance: 0,
//             payload: getPayload('USDT-STETH', ctx.contracts.euler.address),
//         }]},
//         // total supply
//         { call: 'eVaults.eUSDT.totalSupply', equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001]},
//         { call: 'eVaults.eUSDT.totalAssets', equals: [et.units(100_000, 6).sub(et.units('1000', 6)), 0.000001], },
//         { call: 'eVaults.eSTETH.totalSupply', equals: [et.eth('0.611673704450252733'), 0.000001] },
//         { call: 'eVaults.eSTETH.totalAssets', equals: [et.eth('0.611673704450252733'), 0.000001] },
//         // account balances 
//         { call: 'eVaults.eUSDT.balanceOf', args: [ctx.wallet.address], equals: [et.eth(100_000).sub(et.eth('1000')), 0.000001], },
//         { call: 'eVaults.eUSDT.maxWithdraw', args: [ctx.wallet.address], equals: [et.units(100_000, 6).sub(et.units('1000', 6)), 0.000001], },
//         { call: 'eVaults.eSTETH.balanceOf', args: [ctx.wallet.address], equals: [et.eth('0.611673704450252733'), 0.000001] },
//         { call: 'eVaults.eSTETH.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth('0.611673704450252733'), 0.000001]},
//         // handler balances
//         { call: 'tokens.USDT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.STETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .test({
//     desc: 'swap and repay, full debt, USDT - STETH, secondary V2, no output tolerance',
//     forkAtBlock: forkAtBlock('USDT-STETH'),
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDT', for: ctx.wallet.address, amount: 100_000 },
//         { send: 'tokens.USDT.approve', args: [ctx.contracts.eVaults.eUSDT.address, et.MaxUint256], },
//         { send: 'eVaults.eUSDT.deposit', args: [et.MaxUint256], },

//         ...borrowSetup(ctx),
//         { send: 'eVaults.eSTETH.borrow', args: [et.eth(1), ctx.wallet.address] },
//         () => {
//             ctx.stash.secondaryAmountIn = et.eth('39.892390152140367681');
//         },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.USDT.address,
//             underlyingOut: ctx.contracts.tokens.STETH.address,
//             amountIn: et.MaxUint256,
//             amountOut: 0,
//             mode: 1,
//             exactOutTolerance: 0,
//             payload: encodeExactOutputPayload(getPayload('USDT-STETH', ctx.contracts.euler.address), testSwaps['USDT-STETH'].pathV2)
//         }, 0], expectError: 'e/swap-hub/insufficient-output', },
//     ],
// })


// .test({
//     desc: 'swap and repay, full debt, USDT - STETH, secondary V2, with output tolerance',
//     forkAtBlock: forkAtBlock('USDT-STETH'),
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDT', for: ctx.wallet.address, amount: 100_000 },
//         { send: 'tokens.USDT.approve', args: [ctx.contracts.eVaults.eUSDT.address, et.MaxUint256], },
//         { send: 'eVaults.eUSDT.deposit', args: [et.MaxUint256], },
//         ...borrowSetup(ctx),
//         // stETH balance was set in the underlying shares, record balanceOf
//         { call: 'tokens.STETH.balanceOf', args: [ctx.contracts.euler.address], onResult: r => {
//             ctx.stash.preStethBalance = r;
//         } },

//         { send: 'eVaults.eSTETH.borrow', args: [et.eth(1), ctx.wallet.address] },

//         () => {
//             ctx.stash.secondaryAmountIn = et.eth('641.290661');
//             ctx.stash.secondaryAmountInUnderlying = et.units('641.290661', 6);
//         },
//         { send: 'swapHub.swapAndRepay', args: [0, 0, ctx.contracts.swapHandlers.swapHandler1Inch.address, {
//             underlyingIn: ctx.contracts.tokens.USDT.address,
//             underlyingOut: ctx.contracts.tokens.STETH.address,
//             amountIn: et.MaxUint256,
//             amountOut: 0,
//             mode: 1,
//             exactOutTolerance: 2,
//             payload: encodeExactOutputPayload(getPayload('USDT-STETH', ctx.contracts.euler.address), testSwaps['USDT-STETH'].pathV2)
//         }, 0]},
//         // total supply
//         { call: 'eVaults.eUSDT.totalSupply', equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.00001]},
//         { call: 'eVaults.eUSDT.totalAssets', equals: () => [et.units(100_000, 6).sub(et.units('1000', 6)).sub(ctx.stash.secondaryAmountInUnderlying), 0.00001], },
//         { call: 'eVaults.eSTETH.totalSupply', equals: () => [ctx.stash.preStethBalance, 0.00001] },
//         { call: 'eVaults.eSTETH.totalAssets', equals: () => [ctx.stash.preStethBalance, 0.00001] },
//         // account balances 
//         { call: 'eVaults.eUSDT.balanceOf', args: [ctx.wallet.address], equals: () => [et.eth(100_000).sub(et.eth('1000')).sub(ctx.stash.secondaryAmountIn), 0.00001], },
//         { call: 'eVaults.eUSDT.maxWithdraw', args: [ctx.wallet.address], equals: () => [et.units(100_000, 6).sub(et.units('1000', 6)).sub(ctx.stash.secondaryAmountInUnderlying), 0.00001], },
//         { call: 'eVaults.eSTETH.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'eVaults.eSTETH.maxWithdraw', args: [ctx.wallet.address], equals: 0},

//         // some dust debt left
//         { call: 'eVaults.eSTETH.debtOf', args: [ctx.wallet.address], equals: [0, '0.000000000000000002'] },
//         // handler balances
//         { call: 'tokens.USDT.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//         { call: 'tokens.STETH.balanceOf', args: [ctx.contracts.swapHandlers.swapHandler1Inch.address], assertEql: 0 },
//     ],
// })


// .run();

// TODO

// const et = require('./lib/eTestLib');

// et.testSet({
//     desc: 'permit on mainnet fork',
//     fixture: 'mainnet-fork',
//     timeout: 200_000,
//     forkAtBlock: 14200000,
//     preActions: ctx => [
//         { action: 'setMarketConfigRMC', tok: 'USDC', config: { collateralFactor: .4}, },
//     ]
// })


// .test({
//     desc: 'EIP2612 standard permit - USDC',

//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'USDC', signer: ctx.wallet, spender: ctx.contracts.eVaults.eUSDC.address, value: et.units(10, 6), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.USDC.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eUSDC.address,
//                 et.units(10, 6),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eUSDC.deposit', args: [et.units(10, 6), ctx.wallet.address], },
//         ], },
//         { call: 'eVaults.eUSDC.maxWithdraw', args: [ctx.wallet.address], equals: [et.units(10, 6), '0.000000000001'] },
//         { call: 'tokens.USDC.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDC.address], assertEql: 0, },
//     ],
// })



// .test({
//     desc: 'EIP2612 permit with salt - GRT',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'GRT', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'GRT', signer: ctx.wallet, spender: ctx.contracts.eVaults.eGRT.address, value: et.eth(10), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.GRT.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eGRT.address,
//                 et.eth(10),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eGRT.deposit', args: [et.eth(10), ctx.wallet.address], },
//         ], },
//         { call: 'eVaults.eGRT.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(10), '0.000000000001'], },
//         { call: 'tokens.GRT.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eGRT.address], assertEql: 0, },
//     ],
// })


// .test({
//     desc: 'Allowed type permit - DAI',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'DAI', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'DAI', signer: ctx.wallet, spender: ctx.contracts.eVaults.eDAI.address, value: true, deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.DAI.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eDAI.address,
//                 () => ctx.stash.permit.nonce,
//                 et.MaxUint256,
//                 true,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eDAI.deposit', args: [et.eth(10), ctx.wallet.address], },
//         ], },
//         { call: 'eVaults.eDAI.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(10), '0.000000000001'], },

//         // remove allowance
//         { action: 'signPermit', token: 'DAI', signer: ctx.wallet, spender: ctx.contracts.eVaults.eDAI.address, value: false, deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { send: 'tokens.DAI.permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)', args: [
//             ctx.wallet.address,
//             ctx.contracts.eVaults.eDAI.address,
//             () => ctx.stash.permit.nonce,
//             et.MaxUint256,
//             false,
//             () => ctx.stash.permit.signature.v,
//             () => ctx.stash.permit.signature.r,
//             () => ctx.stash.permit.signature.s
//         ], },
//         { call: 'tokens.DAI.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eDAI.address], assertEql: 0, },
//     ],
// })


// .test({
//     desc: 'Packed type permit - YVBOOST',
//     actions: ctx => [
//         { action: 'signPermit', token: 'YVBOOST', signer: ctx.wallet, spender: ctx.contracts.eVaults.eYVBOOST.address, value: et.eth(10), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { send: 'tokens.YVBOOST.permit(address,address,uint256,uint256,bytes)', args: [
//             ctx.wallet.address,
//             ctx.contracts.eVaults.eYVBOOST.address,
//             et.eth(10),
//             et.MaxUint256,
//             () => ctx.stash.permit.rawSignature,
//         ], },
//         { call: 'tokens.YVBOOST.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eYVBOOST.address], assertEql: et.eth(10), },
//     ],
// })


// .test({
//     desc: 'Incorrect signer',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'USDC', signer: ctx.wallet2, spender: ctx.contracts.eVaults.eUSDC.address, value: et.units(10, 6), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.USDC.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eUSDC.address,
//                 et.units(10, 6),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eUSDC.deposit', args: [et.units(10, 6), ctx.wallet.address], },
//         ], expectError: 'EIP2612: invalid signature'},
//     ],
// })


// .test({
//     desc: 'Incorrect spender',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'USDC', signer: ctx.wallet, spender: ctx.contracts.evc.address, value: et.units(10, 6), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.USDC.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eUSDC.address,
//                 et.units(10, 6),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eUSDC.deposit', args: [et.units(10, 6), ctx.wallet.address], },
//         ], expectError: 'EIP2612: invalid signature'},
//     ],
// })


// .test({
//     desc: 'Past deadline',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'USDC', signer: ctx.wallet, spender: ctx.contracts.eVaults.eUSDC.address, value: et.units(10, 6), deadline: 1,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.USDC.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eUSDC.address,
//                 et.units(10, 6),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eUSDC.deposit', args: [et.units(10, 6), ctx.wallet.address], },
//         ], expectError: 'EIP2612: invalid signature'},
//     ],
// })


// .test({
//     desc: 'Permit value too low',
//     actions: ctx => [
//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 100_000 },
//         { action: 'signPermit', token: 'USDC', signer: ctx.wallet, spender: ctx.contracts.eVaults.eUSDC.address, value: et.units(5, 6), deadline: et.MaxUint256,
//             onResult: r => {
//                 ctx.stash.permit = r;
//             },
//         },
//         { action: 'sendBatch', batch: [
//             { send: 'tokens.USDC.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
//                 ctx.wallet.address,
//                 ctx.contracts.eVaults.eUSDC.address,
//                 et.units(10, 6),
//                 et.MaxUint256,
//                 () => ctx.stash.permit.signature.v,
//                 () => ctx.stash.permit.signature.r,
//                 () => ctx.stash.permit.signature.s
//             ], },
//             { send: 'eVaults.eUSDC.deposit', args: [et.units(10, 6), ctx.wallet.address], },
//         ], expectError: 'EIP2612: invalid signature'},
//     ],
// })


// .run();

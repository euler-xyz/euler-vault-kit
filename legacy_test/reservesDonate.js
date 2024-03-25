const et = require('./lib/eTestLib');

// et.testSet({
//     desc: "donate to reserves",

//     preActions: ctx => {
//         let actions = [];

//         for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
//             actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.units(100)], });
//             actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });

//             actions.push({ from, send: 'tokens.TST9.mint', args: [from.address, et.units(100, 6)], });
//             actions.push({ from, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], });
//         }

//         return actions;
//     },
// })



// .test({
//     desc: "donate to reserves - basic",
//     actions: ctx => [
//         { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address] },
//         { call: 'eVaults.eTST.totalSupply', equals: [et.eth(10), '0.000000001' ], onResult: r => {
//             ctx.stash.ts = r;
//         } },

//         { send: 'eVaults.eTST.donateToReserves', args: [et.eth(1)], onLogs: logs => {
//             et.expect(logs.length).to.equal(4);

//             et.expect(logs[0].name).to.equal('RequestDonate');
//             et.expect(logs[0].args.account).to.equal(ctx.wallet.address);
//             et.expect(logs[0].args.amount).to.equal(et.eth(1));

//             et.expect(logs[1].name).to.equal('DecreaseBalance');
//             et.expect(logs[1].args.market).to.equal(ctx.contracts.eVaults.eTST.address);
//             et.expect(logs[1].args.account).to.equal(ctx.wallet.address);
//             et.expect(logs[1].args.amount).to.equal(et.eth(1));

//             et.expect(logs[2].name).to.equal('Transfer');
//             et.expect(logs[2].args.from).to.equal(ctx.wallet.address);
//             et.expect(logs[2].args.to).to.equal(et.AddressZero);
//             et.expect(logs[2].args.value).to.equal(et.eth(1));
//         } },

//         { call: 'eVaults.eTST.totalSupply', equals: () => ctx.stash.ts },
//         { call: 'eVaults.eTST.accumulatedFees', equals: et.eth(1).add(et.DefaultReserve) },
//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.eth(9), '0.000000001'] },
//         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], equals: et.eth(10), },
//     ],
// })



// .test({
//     desc: "donate to reserves - non-18 decimal places token",
//     actions: ctx => [
//         { send: 'eVaults.eTST9.deposit', args: [et.units(10, 6), ctx.wallet.address] },
//         { call: 'eVaults.eTST9.totalSupply', equals: [et.eth(10), '0.000000001'], onResult: r => {
//             ctx.stash.ts = r;
//         } },

//         { send: 'eVaults.eTST9.donateToReserves', args: [et.eth(1)], onLogs: logs => {
//             et.expect(logs.length).to.equal(4);

//             et.expect(logs[0].name).to.equal('RequestDonate');
//             et.expect(logs[0].args.account).to.equal(ctx.wallet.address);
//             et.expect(logs[0].args.amount).to.equal(et.eth(1));

//             et.expect(logs[1].name).to.equal('DecreaseBalance');
//             et.expect(logs[1].args.market).to.equal(ctx.contracts.eVaults.eTST9.address);
//             et.expect(logs[1].args.account).to.equal(ctx.wallet.address);
//             et.expect(logs[1].args.amount).to.equal(et.eth(1));

//             et.expect(logs[2].name).to.equal('Transfer');
//             et.expect(logs[2].args.from).to.equal(ctx.wallet.address);
//             et.expect(logs[2].args.to).to.equal(et.AddressZero);
//             et.expect(logs[2].args.value).to.equal(et.eth(1));
//         } },

//         { call: 'eVaults.eTST9.totalSupply', equals: () => ctx.stash.ts },
//         { call: 'eVaults.eTST9.totalAssets', equals: [et.units(10, 6), '0.000000001'] },
//         { call: 'eVaults.eTST9.accumulatedFees', equals: et.eth(1).add(et.DefaultReserve) },
//         { call: 'eVaults.eTST9.accumulatedFeesAssets', equals: [et.units(1, 6), '0.000000001'] },
//         { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], equals: [et.eth(9), '0.000000001'] },
//         { call: 'eVaults.eTST9.maxWithdraw', args: [ctx.wallet.address], equals: [et.units(9, 6), '0.000000001'] },
//         { call: 'tokens.TST9.balanceOf', args: [ctx.contracts.eVaults.eTST9.address], equals: et.units(10, 6), },
//     ],
// })



// .test({
//     desc: "donate to reserves - max uint",
//     actions: ctx => [
//         { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address] },

//         { send: 'eVaults.eTST.donateToReserves', args: [et.MaxUint256] },

//         { call: 'eVaults.eTST.totalSupply', equals: [et.eth(10), '0.000000001'] },
//         { call: 'eVaults.eTST.accumulatedFees', equals: et.eth(10).add(et.DefaultReserve) },
//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: 0 },
//         { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], equals: et.eth(10), },
//     ],
// })



// .test({
//     desc: "donate to reserves - insufficient balance",
//     actions: ctx => [
//         { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address]},

//         { send: 'eVaults.eTST.donateToReserves', args: [et.eth(11)], expectError: 'E_InsufficientBalance' },
//     ],
// })



// .run();

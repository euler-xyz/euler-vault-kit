// const et = require('./lib/eTestLib');

// const EULTokenPermitSignature = async (ctx, ownerWallet, spenderAddress, value, deadline) => {
//     // EIP-2612 message specification
//     const typesPermitObj = {
//         "Permit": [{
//             "name": "owner",
//             "type": "address"
//             },
//             {
//               "name": "spender",
//               "type": "address"
//             },
//             {
//               "name": "value",
//               "type": "uint256"
//             },
//             {
//               "name": "nonce",
//               "type": "uint256"
//             },
//             {
//               "name": "deadline",
//               "type": "uint256"
//             }
//           ],
//     };
//     const typesPermitStr = 'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)';
//     const typesPermitBytes = et.ethers.utils.toUtf8Bytes(typesPermitStr);
//     const abiPermit = [
//         'function name() external view returns (string)',
//         'function DOMAIN_SEPARATOR() external view returns (bytes32)',
//         'function nonces(address owner) external view returns (uint)',
//         'function PERMIT_TYPEHASH() external view returns (bytes32)'
//     ];

//     const signTypedData = ownerWallet.signTypedData ? ownerWallet.signTypedData.bind(ownerWallet) : ownerWallet._signTypedData.bind(ownerWallet);
//     const TypedDataEncoder = et.ethers.utils.TypedDataEncoder ? et.ethers.utils.TypedDataEncoder : et.ethers.utils._TypedDataEncoder;
//     const contract = new et.ethers.Contract(ctx.contracts.tokens.EUL.address, abiPermit, ownerWallet);
//     const name = await contract.name();
//     const version = '1'; // hardcoded
//     const chainId = ownerWallet.provider.network.chainId;
//     const nonce = await contract.nonces(ownerWallet.address);

//     // EIP-712 domain specification
//     const domain = {
//         name, 
//         version, 
//         chainId, 
//         verifyingContract: ctx.contracts.tokens.EUL.address
//     };

//     // EIP-2612 based message signed using the EIP-712 specification
//     const rawSignature = await signTypedData(domain, typesPermitObj, {
//         owner: ownerWallet.address,
//         spender: spenderAddress,
//         value,
//         nonce,
//         deadline
//     });

//     return {
//         domainSeparatorMatch: TypedDataEncoder.hashDomain(domain) === await contract.DOMAIN_SEPARATOR(),
//         permitTypehashMatch: et.ethers.utils.keccak256(typesPermitBytes) === await contract.PERMIT_TYPEHASH(),
//         signature: et.ethers.utils.splitSignature(rawSignature),
//     }
// }

// et.testSet({
//     desc: "staking",

//     preActions: ctx => {
//         let actions = [];
//         for (let from of [ctx.wallet, ctx.wallet2]) {
//             actions.push({ from, send: 'tokens.EUL.mint', args: [from.address, et.eth(1)], });
//             actions.push({ from, send: 'tokens.EUL.approve', args: [ctx.contracts.eulStakes.address, et.MaxUint256,], });
//         }
//         actions.push({ from: ctx.wallet3, send: 'tokens.EUL.mint', args: [ctx.wallet3.address, et.units(1, 36)], });
//         actions.push({ from: ctx.wallet3, send: 'tokens.EUL.approve', args: [ctx.contracts.eulStakes.address, et.MaxUint256,], });
    
//         // no approvals!
//         for (let from of [ctx.wallet4, ctx.wallet5]) {
//             actions.push({ from, send: 'tokens.EUL.mint', args: [from.address, et.eth(1)], });
//         }        
//         return actions;
//     },
// })

// .test({
//     desc: "simple stake and unstake",
//     actions: ctx => [
//         // single stake operation
//         { from: ctx.wallet, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(.1)
//             },
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Stake event
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.1)));
//         }},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(.9), },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address, ctx.contracts.tokens.TST.address], assertEql: et.eth(.1), },

//         // single unstake operation
//         { from: ctx.wallet, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(-0.1)
//             },
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Stake event
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(0)));
//         }},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address, ctx.contracts.tokens.TST.address], assertEql: et.eth(0), },
//     ],
// })

// .test({
//     desc: "staking/unstaking with various underlying",
//     actions: ctx => [
//         // double stake operation
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(.2)
//             },
//             {
//                 underlying: ctx.contracts.tokens.TST2.address,
//                 amount: et.eth(.3)
//             },            
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Two Stake events
//             et.expect(logs.length).to.equal(2); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.2)));

//             et.expect(logs[1].name).to.equal('Stake');
//             et.expect(logs[1].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[1].args.underlying).to.equal(ctx.contracts.tokens.TST2.address);
//             et.expect(logs[1].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[1].args.newAmount.eq(et.eth(.3)));            
//         }},
        
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.5), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address], assertEql: et.eth(.2), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.3), },

//         // multiple stake/unstake operations (delta positive)
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(.1)
//             },
//             {
//                 underlying: ctx.contracts.tokens.TST2.address,
//                 amount: et.eth(-0.2)
//             },  
//             {
//                 underlying: ctx.contracts.tokens.TST3.address,
//                 amount: et.eth(0.3)
//             },              
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Three Stake events
//             et.expect(logs.length).to.equal(3); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.3)));

//             et.expect(logs[1].name).to.equal('Stake');
//             et.expect(logs[1].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[1].args.underlying).to.equal(ctx.contracts.tokens.TST2.address);
//             et.expect(logs[1].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[1].args.newAmount.eq(et.eth(.1)));   

//             et.expect(logs[2].name).to.equal('Stake');
//             et.expect(logs[2].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[2].args.underlying).to.equal(ctx.contracts.tokens.TST3.address);
//             et.expect(logs[2].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[2].args.newAmount.eq(et.eth(.3)));               
//         }},

//         // delta = 0.2
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.3), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(.3), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.1), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST3.address], assertEql: et.eth(.3), },

//         // multiple stake/unstake operations (delta negative)
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(-0.3)
//             },
//             {
//                 underlying: ctx.contracts.tokens.TST2.address,
//                 amount: et.eth(.2)
//             },  
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Two Stake events
//             et.expect(logs.length).to.equal(2); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(0)));

//             et.expect(logs[1].name).to.equal('Stake');
//             et.expect(logs[1].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[1].args.underlying).to.equal(ctx.contracts.tokens.TST2.address);
//             et.expect(logs[1].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[1].args.newAmount.eq(et.eth(.3)));           
//         }},

//         // delta = -0.1
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.4), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.3), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST3.address], assertEql: et.eth(.3), },

//         // multiple stake/unstake operations (delta neutral)
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.eth(.1)
//             },
//             {
//                 underlying: ctx.contracts.tokens.TST2.address,
//                 amount: et.eth(0)
//             },
//             {
//                 underlying: ctx.contracts.tokens.TST3.address,
//                 amount: et.eth(-0.1)
//             },
//         ]], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Two Stake events (event for TST2 underlying not emitted due to 0 amount)
//             et.expect(logs.length).to.equal(2); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.1)));

//             et.expect(logs[1].name).to.equal('Stake');
//             et.expect(logs[1].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[1].args.underlying).to.equal(ctx.contracts.tokens.TST3.address);
//             et.expect(logs[1].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[1].args.newAmount.eq(et.eth(.2)));           
//         }},

//         // delta = 0
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.4), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(.1), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.3), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST3.address], assertEql: et.eth(.2), },

//         // revert on insufficient staked error
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST2.address,
//                 amount: et.eth(-0.3).sub(1)
//             },
//         ]], expectError: 'insufficient staked'},

//         // no change expected
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.4), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address], assertEql: et.eth(.1), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.3), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST3.address], assertEql: et.eth(.2), },         
//     ],
// })

// .test({
//     desc: "staking boundary amounts",
//     actions: ctx => [
//         { from: ctx.wallet3, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.units(1, 36).sub(1)
//             },
//         ]]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: 1 },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.TST.address], assertEql: et.units(1, 36).sub(1) },

//         { from: ctx.wallet3, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: 1
//             },
//         ]]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: 0 },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.TST.address], assertEql: et.units(1, 36) },

//         // revert on amount out of range
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.units(-1, 36)
//             },
//         ]], expectError: 'amount out of range'},

//         { from: ctx.wallet3, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.units(-1, 36).add(1)
//             },
//         ]]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: et.units(1, 36).sub(1) },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.TST.address], assertEql: 1 },

//         { from: ctx.wallet3, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: -1
//             },
//         ]]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: et.units(1, 36) },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.TST.address], assertEql: 0 },

//         // revert on amount out of range
//         { from: ctx.wallet2, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.TST.address,
//                 amount: et.units(1, 36)
//             },
//         ]], expectError: 'amount out of range'},
//     ],
// })

// .test({
//     desc: "stake gift",
//     actions: ctx => [
//         { from: ctx.wallet, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet2.address,
//             ctx.contracts.tokens.TST.address,
//             et.eth(.15)
//         ], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Stake event
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.15)));
//         }},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(.85), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(1),  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST.address], assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address], assertEql: et.eth(.15), },

//         { from: ctx.wallet, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet2.address,
//             ctx.contracts.tokens.TST2.address,
//             et.eth(.25)
//         ], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Stake event
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet2.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST2.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.25)));
//         }},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(.6), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(1),  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST.address],  assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(.15), },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST2.address], assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.25), },

//         // stake gift of 0
//         { from: ctx.wallet, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet2.address,
//             ctx.contracts.tokens.TST.address,
//             et.eth(0)
//         ]},

//         // nothing should be changed
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(.6), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(1),  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST.address],  assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(.15), },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST2.address], assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.25), },

//         { from: ctx.wallet2, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet.address,
//             ctx.contracts.tokens.TST2.address,
//             et.eth(.35)
//         ], onLogs: logs => {
//             logs = logs.filter(l => l.address === ctx.contracts.eulStakes.address);

//             // Stake event
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('Stake');
//             et.expect(logs[0].args.who).to.equal(ctx.wallet.address);
//             et.expect(logs[0].args.underlying).to.equal(ctx.contracts.tokens.TST2.address);
//             et.expect(logs[0].args.sender).to.equal(ctx.wallet2.address);
//             et.assert(logs[0].args.newAmount.eq(et.eth(.35)));
//         }},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(.6), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(.65),  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST.address],  assertEql: et.eth(0), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST.address],  assertEql: et.eth(.15), },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.TST2.address], assertEql: et.eth(.35), },
//         { call: 'eulStakes.staked', args: [ctx.wallet2.address, ctx.contracts.tokens.TST2.address], assertEql: et.eth(.25), },    
//     ],
// })

// .test({
//     desc: "stake gift boundary amount",
//     actions: ctx => [
//         { from: ctx.wallet3, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet.address,
//             ctx.contracts.tokens.EUL.address,
//             et.units(1, 36).sub(1)
//         ]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(1), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: 1,  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.EUL.address], assertEql: et.units(1, 36).sub(1), },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.EUL.address], assertEql: 0, }, 

//         { from: ctx.wallet, send: 'eulStakes.stake', args: [[
//             {
//                 underlying: ctx.contracts.tokens.EUL.address,
//                 amount: et.units(-1, 36).add(1)
//             },
//         ]]},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(1).add(et.units(1, 36).sub(1)), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: 1,  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.EUL.address], assertEql: 0, },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.EUL.address], assertEql: 0, }, 

//         { from: ctx.wallet, send: 'eulStakes.stakeGift', args: [
//             ctx.wallet3.address,
//             ctx.contracts.tokens.EUL.address,
//             et.units(1, 36)
//         ], expectError: 'amount out of range'},

//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet.address],  assertEql: et.eth(1).add(et.units(1, 36).sub(1)), },
//         { call: 'tokens.EUL.balanceOf', args: [ctx.wallet3.address], assertEql: 1,  },
//         { call: 'eulStakes.staked', args: [ctx.wallet.address,  ctx.contracts.tokens.EUL.address], assertEql: 0, },
//         { call: 'eulStakes.staked', args: [ctx.wallet3.address, ctx.contracts.tokens.EUL.address], assertEql: 0, },         
//     ],
// })

// .test({
//     desc: "stake permit",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             const owner = ctx.wallet4;
//             const spenderAddress = ctx.contracts.eulStakes.address;
//             const permitValue = et.eth(.5);
//             const deadline = et.MaxUint256;
//             const result = await EULTokenPermitSignature(ctx, owner, spenderAddress, permitValue, deadline);
//             const args = [[
//                 {
//                     underlying: ctx.contracts.tokens.EUL.address,
//                     amount: et.eth(.05)
//                 },
//                 {
//                     underlying: ctx.contracts.tokens.TST.address,
//                     amount: et.eth(.1)
//                 },  
//                 {
//                     underlying: ctx.contracts.tokens.TST2.address,
//                     amount: et.eth(.15)
//                 }
//             ], permitValue, deadline, result.signature.v, result.signature.r, result.signature.s];

//             let errMsg = '';
//             try {
//                 await (await ctx.contracts.eulStakes.connect(owner).stakePermit(...args)).wait();
//             } catch (e) {
//                 errMsg = e.message;
//             }

//             et.expect(errMsg).to.equal('');
//             et.expect(result.domainSeparatorMatch).to.equal(true);
//             et.expect(result.permitTypehashMatch).to.equal(true);
//             et.expect(await ctx.contracts.tokens.EUL.balanceOf(owner.address)).to.equal(et.eth(.7));
//             et.expect(await ctx.contracts.tokens.EUL.allowance(owner.address, spenderAddress)).to.equal(et.eth(.2));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.EUL.address)).to.equal(et.eth(.05));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.TST.address)).to.equal(et.eth(.1));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.TST2.address)).to.equal(et.eth(.15));
//         }, },


//         { action: 'cb', cb: async () => {
//             const owner = ctx.wallet4;
//             const spenderAddress = ctx.contracts.eulStakes.address;
//             const permitValue = et.eth(.2);
//             const deadline = et.MaxUint256;
//             const result = await EULTokenPermitSignature(ctx, owner, spenderAddress, permitValue, deadline);
//             const args = [[
//                 {
//                     underlying: ctx.contracts.tokens.EUL.address,
//                     amount: et.eth(.2)
//                 },
//                 {
//                     underlying: ctx.contracts.tokens.TST.address,
//                     amount: et.eth(.1)
//                 },  
//                 {
//                     underlying: ctx.contracts.tokens.TST2.address,
//                     amount: et.eth(-0.1)
//                 }
//             ], permitValue, deadline, result.signature.v, result.signature.r, result.signature.s];

//             let errMsg = '';
//             try {
//                 await (await ctx.contracts.eulStakes.connect(owner).stakePermit(...args)).wait();
//             } catch (e) {
//                 errMsg = e.message;
//             }

//             et.expect(errMsg).to.equal('');
//             et.expect(result.domainSeparatorMatch).to.equal(true);
//             et.expect(result.permitTypehashMatch).to.equal(true);
//             et.expect(await ctx.contracts.tokens.EUL.balanceOf(owner.address)).to.equal(et.eth(.5));
//             et.expect(await ctx.contracts.tokens.EUL.allowance(owner.address, spenderAddress)).to.equal(et.eth(0));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.EUL.address)).to.equal(et.eth(.25));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.TST.address)).to.equal(et.eth(.2));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.TST2.address)).to.equal(et.eth(.05));
//         }, }, 


//         // should revert due to incorrect permission signer
//         { action: 'cb', cb: async () => {
//             const owner = ctx.wallet4;
//             const spenderAddress = ctx.contracts.eulStakes.address;
//             const permitValue = et.eth(.5);
//             const deadline = et.MaxUint256;
//             const result = await EULTokenPermitSignature(ctx, owner, spenderAddress, permitValue, deadline);
//             const args = [[
//                 {
//                     underlying: ctx.contracts.tokens.EUL.address,
//                     amount: et.eth(.5)
//                 }
//             ], permitValue, deadline, result.signature.v, result.signature.r, result.signature.s];

//             let errMsg = '';
//             try {
//                 await (await ctx.contracts.eulStakes.connect(ctx.wallet5).stakePermit(...args)).wait();
//             } catch (e) {
//                 errMsg = e.message;
//             }

//             et.expect(errMsg).to.contain('permit: unauthorized');
//             et.expect(result.domainSeparatorMatch).to.equal(true);
//             et.expect(result.permitTypehashMatch).to.equal(true);
//         }, },


//         // should pass when signer changed
//         { action: 'cb', cb: async () => {
//             const owner = ctx.wallet5;
//             const spenderAddress = ctx.contracts.eulStakes.address;
//             const permitValue = et.eth(.5);
//             const deadline = et.MaxUint256;
//             const result = await EULTokenPermitSignature(ctx, owner, spenderAddress, permitValue, deadline);
//             const args = [[
//                 {
//                     underlying: ctx.contracts.tokens.EUL.address,
//                     amount: et.eth(.5)
//                 }
//             ], permitValue, deadline, result.signature.v, result.signature.r, result.signature.s];

//             let errMsg = '';
//             try {
//                 await (await ctx.contracts.eulStakes.connect(owner).stakePermit(...args)).wait();
//             } catch (e) {
//                 errMsg = e.message;
//             }

//             et.expect(errMsg).to.equal('');
//             et.expect(result.domainSeparatorMatch).to.equal(true);
//             et.expect(result.permitTypehashMatch).to.equal(true);
//             et.expect(await ctx.contracts.tokens.EUL.balanceOf(owner.address)).to.equal(et.eth(.5));
//             et.expect(await ctx.contracts.tokens.EUL.allowance(owner.address, spenderAddress)).to.equal(et.eth(0));
//             et.expect(await ctx.contracts.eulStakes.staked(owner.address, ctx.contracts.tokens.EUL.address)).to.equal(et.eth(.5));
//         }, },        
//     ],
// })

// .run();

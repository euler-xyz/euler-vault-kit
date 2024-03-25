// const et = require('./lib/eTestLib');
// const merkleTree = require('./lib/merkle-tree');

// et.testSet({
//     desc: "EUL distributor",
//     timeout: 100_000,

//     preActions: ctx => {
//         let actions = [];
        
//         for(let token of ['EUL', 'TST', 'TST2', 'TST3']) {
//             actions.push({send: `tokens.${token}.mint`, args: [ctx.contracts.eulDistributor.address, et.eth(1000000)], });
//         }
//         return actions;
//     },
// })

// .test({
//     desc: "merkle distribution of various tokens",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             ctx.stash.dist = [
//                 {
//                     account: '0x315d371453689e66a6bb8b11446893850978a3f2',
//                     token: ctx.contracts.tokens.EUL.address,
//                     claimable: et.ethers.utils.parseEther('120.5'),
//                 },
//                 {
//                     account: '0x1981e522d4e97acd6af4b9bb85631753325a7727',
//                     token: ctx.contracts.tokens.TST.address,
//                     claimable: et.ethers.utils.parseEther('75'),
//                 },
//                 {
//                     account: '0xfa9fcfe4f223d98f3c777e3fdec949835da32240',
//                     token: ctx.contracts.tokens.TST2.address,
//                     claimable: et.ethers.utils.parseEther('1000'),
//                 },
//                 {
//                     account: '0x93a95f531dafe820a2921917dfb82a604ddff8dc',
//                     token: ctx.contracts.tokens.TST3.address,
//                     claimable: et.ethers.utils.parseEther('47.1'),
//                 },
//             ];
            
//             ctx.stash.merkleRoot = merkleTree.root(ctx.stash.dist);
//             await (await ctx.contracts.eulDistributor.updateRoot(ctx.stash.merkleRoot)).wait();
//         }},

//         { action: 'cb', cb: async () => {
//             for (let item of ctx.stash.dist) {
//                 const account = item.account;
//                 const token = item.token;
//                 const proof = merkleTree.proof(ctx.stash.dist, account, token);
//                 const eulDistInitBal = await (await et.ethers.getContractAt('TestERC20', token)).balanceOf(ctx.contracts.eulDistributor.address);

//                 await (await ctx.contracts.eulDistributor.claim(account, token, proof.item.claimable, proof.witnesses, et.AddressZero)).wait();

//                 et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                 et.expect(await (await et.ethers.getContractAt('TestERC20', token)).balanceOf(account)).to.equal(item.claimable);
//                 et.expect(await (await et.ethers.getContractAt('TestERC20', token)).balanceOf(ctx.contracts.eulDistributor.address))
//                     .to.equal(eulDistInitBal.sub(item.claimable));
//             }
//         }},
//     ],
// })

// .test({
//     desc: "merkle distribution of EUL token",
//     actions: ctx => [
//         // many unique wallets with unique claimable
//         { action: 'cb', cb: async () => {
//             const privateKey = et.ethers.utils.randomBytes(32);
//             ctx.stash.dist = [];
//             ctx.stash.wallet = [];

//             for(let i=0; i<100; i++) {
//                 privateKey[31] = i;
//                 ctx.stash.wallet.push(new et.ethers.Wallet(privateKey, et.ethers.provider));
//                 ctx.stash.dist.push({
//                     account: ctx.stash.wallet[i].address,
//                     token: ctx.contracts.tokens.EUL.address,
//                     claimable: et.ethers.utils.parseEther(((i+1)/20).toString()),
//                 });

//                 // drop some ETH so that new wallets can use it for gas
//                 await hre.network.provider.send("hardhat_setBalance", [ctx.stash.wallet[i].address, '0xffffffffffffffffff']);
//             }
            
//             ctx.stash.merkleRoot = merkleTree.root(ctx.stash.dist);
//             await (await ctx.contracts.eulDistributor.updateRoot(ctx.stash.merkleRoot)).wait();

//             // every other wallet claims full amount
//             for (let [i, item] of ctx.stash.dist.entries()) {
//                 if(i % 2 == 0) {
//                     const account = item.account;
//                     const token = item.token;
//                     const eulDistInitBal = await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address);
    
//                     let errMsg = '';
//                     try {
//                         const proof = merkleTree.proof(ctx.stash.dist, account, token);
//                         await (await ctx.contracts.eulDistributor.connect(ctx.stash.wallet[i])
//                             .claim(account, token, proof.item.claimable, proof.witnesses, et.AddressZero)).wait();
//                     } catch (e) {
//                         errMsg = e.message;
//                     }

//                     et.expect(errMsg).to.equal('');
//                     et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(account)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address))
//                         .to.equal(eulDistInitBal.sub(item.claimable));
//                 }
//             }

//             // next epoch comes, merkle root is updated
//             ctx.stash.dist2 = [];
//             for(let i=0; i<100; i++) {
//                 ctx.stash.dist2.push({
//                     account: ctx.stash.wallet[i].address,
//                     token: ctx.contracts.tokens.EUL.address,
//                     claimable: et.ethers.utils.parseEther(((i+1)/10).toString()),
//                 });
//             }
            
//             ctx.stash.merkleRoot2 = merkleTree.root(ctx.stash.dist2);
//             await (await ctx.contracts.eulDistributor.updateRoot(ctx.stash.merkleRoot2)).wait();        
            
//             // odd wallets claim full amount
//             // even wallets use the old merkle root trying to claim again
//             // for odd wallets, when merkle root is updated again, they can still claim
//             // for even wallets, when merkle root is updated again, proof is invalid as it matches neither previous nor current root
//             for (let [i, item] of ctx.stash.dist2.entries()) {
//                 const account = item.account;
//                 const token = item.token;
//                 const eulDistInitBal = await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address);
    
//                 let errMsg = '';
//                 try {
//                     let proof;
//                     if(i % 2 == 0) {
//                         proof = merkleTree.proof(ctx.stash.dist, account, token);
//                     } else {
//                         proof = merkleTree.proof(ctx.stash.dist2, account, token);
//                     }
//                     await (await ctx.contracts.eulDistributor.connect(ctx.stash.wallet[i])
//                         .claim(account, token, proof.item.claimable, proof.witnesses, et.AddressZero)).wait();
//                 } catch (e) {
//                     errMsg = e.message;
//                 }

//                 // update the root at some point. claim should still be possible using the previous root
//                 if(i == ctx.stash.dist2.length/2) {
//                     await (await ctx.contracts.eulDistributor.updateRoot(et.ethers.utils.randomBytes(32))).wait();
//                 }

//                 if(i % 2 == 0) {
//                     if(i > ctx.stash.dist2.length/2) {
//                         et.expect(errMsg).to.contains('proof invalid/expired');
//                     } else {
//                         et.expect(errMsg).to.contains('already claimed');
//                     }
//                 } else {
//                     et.expect(errMsg).to.equal('');
//                     et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(account)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address))
//                         .to.equal(eulDistInitBal.sub(item.claimable));
//                 }
//             }

//             // even wallets claim the leftovers
//             for (let [i, item] of ctx.stash.dist2.entries()) {
//                 if(i % 2 == 0) {
//                     const account = item.account;
//                     const token = item.token;
//                     const eulDistInitBal = await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address);
//                     const accountInitBal = await ctx.contracts.tokens.EUL.balanceOf(account);
        
//                     let errMsg = '';
//                     try {
//                         const proof = merkleTree.proof(ctx.stash.dist2, account, token);
//                         await (await ctx.contracts.eulDistributor.connect(ctx.stash.wallet[i])
//                             .claim(account, token, proof.item.claimable, proof.witnesses, et.AddressZero)).wait();
//                     } catch (e) {
//                         errMsg = e.message;
//                     }
                    
//                     et.expect(errMsg).to.equal('');
//                     et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(account)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address))
//                         .to.equal(eulDistInitBal.sub(item.claimable).add(accountInitBal));
//                 }
//             }
//         }},
//     ],
// })

// .test({
//     desc: "invalid claim inputs",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             const privateKey = et.ethers.utils.randomBytes(32);
//             ctx.stash.dist = [];
//             ctx.stash.wallet = [];

//             for(let i=0; i<100; i++) {
//                 privateKey[31] = i;
//                 ctx.stash.wallet.push(new et.ethers.Wallet(privateKey, et.ethers.provider));
//                 ctx.stash.dist.push({
//                     account: ctx.stash.wallet[i].address,
//                     token: ctx.contracts.tokens.EUL.address,
//                     claimable: et.ethers.utils.parseEther((i+1).toString())
//                 });

//                 // drop some ETH so that new wallets can use it for gas
//                 await hre.network.provider.send("hardhat_setBalance", [ctx.stash.wallet[i].address, '0xffffffffffffffffff']);
//             }
            
//             ctx.stash.merkleRoot = merkleTree.root(ctx.stash.dist);
//             await (await ctx.contracts.eulDistributor.updateRoot(ctx.stash.merkleRoot)).wait();

//             // prove that incorrect input affects the outcome
//             for (let [i, item] of ctx.stash.dist.entries()) {
//                 let account = item.account;
//                 let token = item.token;
//                 let eulDistInitBal = await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address);
//                 let proof = merkleTree.proof(ctx.stash.dist, account, token);
    
//                 let errMsg = '';
//                 try {
//                     if(i<20) {
//                         // incorrect account
//                         account = et.ethers.utils.hexZeroPad(et.BN(account).add(1).toHexString(), 20);
//                     } else if(i<40) {
//                         // incorrect token
//                         token = et.ethers.utils.hexZeroPad(et.BN(token).add(1).toHexString(), 20);
//                     } else if(i<60) {
//                         // incorrect claimable
//                         proof.item.claimable = et.ethers.utils.hexZeroPad(et.BN(proof.item.claimable).add(1).toHexString(), 32);
//                     } else if(i<80) {
//                         // incorrect proof
//                         proof.witnesses[0] = et.ethers.utils.hexZeroPad(et.BN(proof.witnesses[0]).add(1).toHexString(), 32);
//                     }
//                     await (await ctx.contracts.eulDistributor.connect(ctx.stash.wallet[i])
//                         .claim(account, token, proof.item.claimable, proof.witnesses, et.AddressZero)).wait();
//                 } catch (e) {
//                     errMsg = e.message;
//                 }

//                 if(i < 80) {
//                     et.expect(errMsg).to.contains('proof invalid/expired');    
//                 } else {
//                     et.expect(errMsg).to.equal('');
//                     et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(account)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address))
//                         .to.equal(eulDistInitBal.sub(item.claimable));
//                 }                
//             }
//         }},
//     ],
// })

// .test({
//     desc: "claim with auto-stake",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             const privateKey = et.ethers.utils.randomBytes(32);
//             ctx.stash.dist = [];
//             ctx.stash.wallet = [];
//             ctx.stash.stake = [];

//             for(let i=0; i<100; i++) {
//                 privateKey[31] = i;
//                 ctx.stash.wallet.push(new et.ethers.Wallet(privateKey, et.ethers.provider));

//                 if(i<20) {
//                     // will be auto-staked on behalf of somebody else
//                     ctx.stash.stake.push(ctx.contracts.tokens.EUL.address);
//                     ctx.stash.dist.push({
//                         account: ctx.stash.wallet[i].address,
//                         token: ctx.contracts.tokens.EUL.address,
//                         claimable: et.ethers.utils.parseEther((i+1).toString())
//                     });
//                 } else if(i<40) {
//                     // auto-stake asset other than EUL
//                     ctx.stash.stake.push(ctx.contracts.tokens.EUL.address);
//                     ctx.stash.dist.push({
//                         account: ctx.stash.wallet[i].address,
//                         token: ctx.contracts.tokens.TST.address,
//                         claimable: et.ethers.utils.parseEther((i+1).toString())
//                     });                    
//                 } else if(i<60) {
//                     // auto-stake asset other than EUL
//                     ctx.stash.stake.push(ctx.contracts.tokens.TST.address);
//                     ctx.stash.dist.push({
//                         account: ctx.stash.wallet[i].address,
//                         token: ctx.contracts.tokens.TST2.address,
//                         claimable: et.ethers.utils.parseEther((i+1).toString())
//                     });                    
//                 } else if(i<80) {
//                     ctx.stash.stake.push(ctx.contracts.tokens.EUL.address);
//                     ctx.stash.dist.push({
//                         account: ctx.stash.wallet[i].address,
//                         token: ctx.contracts.tokens.EUL.address,
//                         claimable: et.ethers.utils.parseEther((i+1).toString())
//                     }); 
//                 } else {
//                     ctx.stash.stake.push(ctx.contracts.tokens.TST.address);
//                     ctx.stash.dist.push({
//                         account: ctx.stash.wallet[i].address,
//                         token: ctx.contracts.tokens.EUL.address,
//                         claimable: et.ethers.utils.parseEther((i+1).toString())
//                     });
//                 }

//                 // drop some ETH so that new wallets can use it for gas
//                 await hre.network.provider.send("hardhat_setBalance", [ctx.stash.wallet[i].address, '0xffffffffffffffffff']);
//             }
            
//             ctx.stash.merkleRoot = merkleTree.root(ctx.stash.dist);
//             await (await ctx.contracts.eulDistributor.updateRoot(ctx.stash.merkleRoot)).wait();

//             for (let [i, item] of ctx.stash.dist.entries()) {
//                 const account = item.account;
//                 const token = item.token;
//                 const eulDistInitBal = await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address);
//                 const proof = merkleTree.proof(ctx.stash.dist, account, token);
    
//                 let errMsg = '';
//                 try {
//                     if(i<20) {
//                         // auto-stake on behalf of somebody else: msg.sender != account
//                         await (await ctx.contracts.eulDistributor
//                             .claim(account, token, proof.item.claimable, proof.witnesses, ctx.stash.stake[i])).wait();
//                     } else {
//                         await (await ctx.contracts.eulDistributor.connect(ctx.stash.wallet[i])
//                             .claim(account, token, proof.item.claimable, proof.witnesses, ctx.stash.stake[i])).wait();
//                     }
//                 } catch (e) {
//                     errMsg = e.message;
//                 }

//                 if(i < 20) {
//                     et.expect(errMsg).to.contains('can only auto-stake for yourself');    
//                 } else if(i<60) {
//                     et.expect(errMsg).to.contains('can only auto-stake EUL');    
//                 }
//                  else {
//                     et.expect(errMsg).to.equal('');
//                     et.expect(await ctx.contracts.eulDistributor.claimed(account, token)).to.equal(item.claimable);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(account)).to.equal(0);
//                     et.expect(await ctx.contracts.tokens.EUL.balanceOf(ctx.contracts.eulDistributor.address))
//                         .to.equal(eulDistInitBal.sub(item.claimable));
//                     et.expect(await ctx.contracts.eulStakes.staked(account, ctx.stash.stake[i])).to.equal(item.claimable);
//                 }
//             }
//         }},
//     ],
// })

// // functionality of the root updating has already been tested implicitly.
// // here it is tested whether only owner can update the root
// .test({
//     desc: "transfer ownership & update root",
//     actions: ctx => [
//         { from: ctx.wallet2, send: 'eulDistributor.transferOwnership', args: [ctx.wallet3.address], expectError: 'unauthorized', },
//         { from: ctx.wallet3, send: 'eulDistributor.transferOwnership', args: [ctx.wallet3.address], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet3, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet,  send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)] },

//         { call: 'eulDistributor.owner', assertEql: ctx.wallet.address },
//         { from: ctx.wallet, send: 'eulDistributor.transferOwnership', args: [ctx.wallet2.address], },
//         { call: 'eulDistributor.owner', assertEql: ctx.wallet2.address },

//         { from: ctx.wallet2, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], },
//         { from: ctx.wallet,  send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet3, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet,  send: 'eulDistributor.transferOwnership', args: [ctx.wallet.address],  expectError: 'unauthorized', },
//         { from: ctx.wallet3, send: 'eulDistributor.transferOwnership', args: [ctx.wallet3.address], expectError: 'unauthorized', },

//         { from: ctx.wallet2, send: 'eulDistributor.transferOwnership', args: [ctx.wallet3.address], },
//         { call: 'eulDistributor.owner', assertEql: ctx.wallet3.address },

//         { from: ctx.wallet3, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], },
//         { from: ctx.wallet,  send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet,  send: 'eulDistributor.transferOwnership', args: [ctx.wallet.address], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributor.transferOwnership', args: [ctx.wallet.address], expectError: 'unauthorized', },
//     ],
// })

// .test({
//     desc: "eul distributor owner",
//     actions: ctx => [
//         async () => {
//             let factory = await ethers.getContractFactory('EulDistributorOwner');
//             let eulDistributorOwner = await (await factory.deploy(ctx.contracts.eulDistributor.address, ctx.wallet.address, ctx.wallet2.address)).deployed();
//             ctx.contracts.eulDistributorOwner = eulDistributorOwner;
//         },

//         { from: ctx.wallet, send: 'eulDistributor.transferOwnership', args: [() => ctx.contracts.eulDistributorOwner.address], },

//         // Only wallet2 can update the root, via the owner contract

//         { from: ctx.wallet, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributor.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet, send: 'eulDistributorOwner.updateRoot', args: [et.ethers.utils.randomBytes(32)], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributorOwner.updateRoot', args: [et.ethers.utils.randomBytes(32)], },

//         // Only wallet can change updater, via the owner contract

//         { from: ctx.wallet2, send: 'eulDistributorOwner.changeUpdater', args: [ctx.wallet3.address], expectError: 'unauthorized', },
//         { from: ctx.wallet, send: 'eulDistributorOwner.changeUpdater', args: [ctx.wallet3.address], },

//         // Only wallet can change the owner, via the owner contract

//         { from: ctx.wallet, send: 'eulDistributor.transferOwnership', args: [ctx.wallet2.address], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributor.transferOwnership', args: [ctx.wallet2.address], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributorOwner.changeOwner', args: [ctx.wallet2.address], expectError: 'unauthorized', },
//         { from: ctx.wallet, send: 'eulDistributorOwner.changeOwner', args: [ctx.wallet2.address], },

//         // Change the underlying eulDistributor's owner via the general-purpose execute

//         { from: ctx.wallet, send: 'eulDistributorOwner.execute', args: [et.AddressZero, 0, []], expectError: 'unauthorized', },
//         { from: ctx.wallet2, send: 'eulDistributorOwner.execute', args: [
//             () => ctx.contracts.eulDistributor.address,
//             0,
//             () => ctx.contracts.eulDistributor.interface.encodeFunctionData('transferOwnership', [ctx.wallet4.address]),
//         ], },

//         { call: 'eulDistributor.owner', assertEql: ctx.wallet4.address },
//     ],
// })

// .run();

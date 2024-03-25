// const et = require('./lib/eTestLib');
// const scenarios = require('./lib/scenarios');


// let ts = et.testSet({
//     desc: "self collateralisation",

//     preActions: ctx => [
//         ...scenarios.basicLiquidity()(ctx),

//         { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '1', },
//         { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '1', },
//         { action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '1', },
//         { action: 'setLTV', collateral: 'TST', liability: 'TST3', cf: 0.45 },

//         { send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(100)], },
//         { send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
//         { send: 'eVaults.eTST3.deposit', args: [et.eth(50), ctx.wallet.address], }, // extra for the pool

//         { send: 'tokens.TST.mint', args: [ctx.wallet3.address, et.eth(100)], },
//         { send: 'tokens.TST3.mint', args: [ctx.wallet3.address, et.eth(100)], },

//         // User deposits 0.5 TST, which has CF of 0.75, giving a risk-adjusted asset value of 0.375

//         { from: ctx.wallet3, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },

//         // enTST is a nested vault holding eTST shares
//         { send: 'genericFactory.createProxy', args: [true, ctx.proxyMetadata(ctx.contracts.eVaults.eTST3.address)], onLogs: async logs => {
//           let log = logs.find(l => l.name === 'ProxyCreated');
//           ctx.contracts.enVaults = { enTST3: await ethers.getContractAt('EVault', log.args.proxy) };
//           await ctx.contracts.oracles.priceOracleCore.initPricingConfig(log.args.proxy, 18, true)
//       }},

//     ]
// })




// .test({
//     desc: "self collateralisation with wrapping",
//     actions: ctx => [
//         { from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(0.5), ctx.wallet3.address], },
//         { action: 'setLTV', collateral: 'TST', liability: 'TST3', cf: 0.45 },

//         // wrapped shares set as collateral for the eTST3 debt
//         { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address], },
//         { send: 'eVaults.eTST3.setLTV', args: [
//             ctx.contracts.enVaults.enTST3.address,
//             Math.floor(0.95 * 1e4),
//             0
//         ], },

//         // Now the user tries to mint an amount X of TST3.
//         // Since the self-collateralisation factor is 0.95, then X * .95 of this mint is self-collateralised.
//         // The remaining 5% is supported by TST deposit at asset collateral factor and borrow factor
//         //     liability = X * (1 - 0.95)
//         // Using a risk-adjusted value of 0.375, we can solve for the maximum allowable X:
//         //     0.5 * 0.45 = X * (1 - 0.95)
//         //     X = 4.5
//         { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], },
//         { action: 'sendBatch', from: ctx.wallet3, batch: [
//             { send: 'eVaults.eTST3.loop', args: [et.eth(4.5).add(1), ctx.wallet3.address] },
//             { send: 'eVaults.eTST3.approve', args: [ctx.contracts.enVaults.enTST3.address, et.MaxUint256] },
//             { send: 'enVaults.enTST3.deposit', args: [et.eth(4.5).add(1), et.AddressZero] },
//           ]
//           , expectError: 'E_AccountLiquidity'
//         },
//         { action: 'sendBatch', from: ctx.wallet3, batch: [
//             { send: 'eVaults.eTST3.loop', args: [et.eth(4.5), ctx.wallet3.address] },
//             { send: 'eVaults.eTST3.approve', args: [ctx.contracts.enVaults.enTST3.address, et.MaxUint256] },
//             { send: 'enVaults.enTST3.deposit', args: [et.eth(4.5), et.AddressZero] },
//           ]
//         },

//         { call: 'eVaults.eTST3.accountLiquidityFull', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValues[2], 4.275, 0.001); // 4.5 * 0.95
//             et.equals(r.liabilityValue, 4.5, 0.001);

//         }},

//         { from: ctx.wallet3, send: 'eVaults.eTST2.borrow', args: [et.eth(0.001), ctx.wallet3.address], expectError: 'E_ControllerDisabled' },
//     ],
// })



// .test({
//     desc: "liquidation, topped-up with other collateral",
//     actions: ctx => [
//         { from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(0.5), ctx.wallet3.address], },

//         // wrapped shares set as collateral for the eTST3 debt
//         { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address], },
//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.enVaults.enTST3.address], },
//         { send: 'eVaults.eTST3.setLTV', args: [
//             ctx.contracts.enVaults.enTST3.address,
//             Math.floor(0.95 * 1e4),
//             0
//         ], },
//         { from: ctx.wallet3, send: 'eVaults.eTST3.approve', args: [ctx.contracts.enVaults.enTST3.address, et.MaxUint256] },

//         { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], },
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },

//         { action: 'sendBatch', from: ctx.wallet3, batch: [
//             { send: 'eVaults.eTST3.loop', args: [et.eth(4.5), ctx.wallet3.address] },
//             { send: 'enVaults.enTST3.deposit', args: [et.eth(4.5), et.AddressZero] },
//           ]
//         },

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue, 4.5, 0.001);
//             et.equals(r.liabilityValue, 4.5, 0.001);
//         }},

//         { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmFixed', },
//         { action: 'checkpointTime', },

//         { action: 'jumpTimeAndMine', time: 86400 * 7, },
//         { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', },

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue, 4.5005, .0001); // earned a little bit of interest
//             et.equals(r.liabilityValue, 4.5086, .0001); // accrued more

//             ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue)
//         }},

//         // Liquidate the self collateral

//         { action: 'snapshot', },
//         { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', },
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], onResult: r => ctx.stash.originalDebt = r, },

//         { call: 'eVaults.eTST3.checkLiquidation', args: [ctx.wallet.address, ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address],
//           onResult: async r => {
//               ctx.stash.maxRepay = r.maxRepay;
//               ctx.stash.maxYield = r.maxYield;

//               const yieldAssets = await ctx.contracts.eVaults.eTST3.convertToAssets(r.maxYield);
//               const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
//           }
//         },
//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
//             et.equals(assets, 0.5, '0.000000001')
//         },},
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, '4.5005', '.0001')
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: ['4.5086', '.0001'], },

//         { send: 'eVaults.eTST3.liquidate', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address, () => ctx.stash.maxRepay, 0], },

//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
//             et.equals(assets, 0.5, '0.000000001')
//         },},
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, 0)
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: () => [ctx.stash.originalDebt.sub(ctx.stash.maxRepay), .001], },

//         { action: 'revert', },

//         // Liquidate the self collateral with override

//         { action: 'snapshot', },
//         { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', },
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], onResult: r => ctx.stash.originalDebt = r, },

//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },

//         { send: 'eVaults.eTST3.setLTV', args: [
//             ctx.contracts.eVaults.eTST.address,
//             Math.floor(0.43 * 1e4),
//             0,
//         ], },

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue, 4.49, 0.001);
//             et.equals(r.liabilityValue, 4.5086, 0.0001);
//             ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue)
//         }, },

//         { call: 'eVaults.eTST3.checkLiquidation', args: [ctx.wallet.address, ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address],
//           onResult: async r => {
//               ctx.stash.maxRepay = r.maxRepay;
//               ctx.stash.maxYield = r.maxYield;

//               const yieldAssets = await ctx.contracts.eVaults.eTST3.convertToAssets(r.maxYield);
//               const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
//           }
//         },

//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
//             et.equals(assets, 0.5, '0.000000001')
//         },},
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, '4.5005', '.0001')
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: ['4.5086', '.0001'], },

//         { send: 'eVaults.eTST3.liquidate', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address, () => ctx.stash.maxRepay, 0], },


//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
//             et.equals(assets, 0.5, '0.000000001')
//         },},
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, 0)
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: () => [ctx.stash.originalDebt.sub(ctx.stash.maxRepay), .001], },

//         { action: 'revert', },


//         // Liquidate the other collateral (TST)

//         { action: 'snapshot', },

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {

//             ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue)
//         }, },

//         { call: 'eVaults.eTST3.checkLiquidation', args: [ctx.wallet.address, ctx.wallet3.address, ctx.contracts.eVaults.eTST.address],
//           onResult: async r => {
//               ctx.stash.maxRepay = r.maxRepay;
//               ctx.stash.maxYield = r.maxYield;

//               const yieldAssets = await ctx.contracts.eVaults.eTST.convertToAssets(r.maxYield);
//               const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST.address, ctx.contracts.tokens.WETH.address)
//               const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
//           }
//         },

//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, 4.500, .001)
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], onResult: r => ctx.stash.originalDebt = r, },

//         { send: 'eVaults.eTST3.liquidate', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address, () => ctx.stash.maxRepay, 0], },

//         // Health score is above 1 because all TST collateral has been consumed, and the extra remaining TST3 counts towards collateral value

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue / r.liabilityValue, 1.066, .001);
//         }},

//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], equals: [0, .000001], },
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, 4.500, .001)
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: () => [ctx.stash.originalDebt.sub(ctx.stash.maxRepay), .001], },

//         { action: 'revert', },
//     ],
// })



// .test({
//     desc: "liquidation, topped-up with self-collateral",
//     actions: ctx => [
//         { from: ctx.wallet3, send: 'eVaults.eTST3.approve', args: [ctx.contracts.enVaults.enTST3.address, et.MaxUint256] },
//         { from: ctx.wallet3, send: 'eVaults.eTST3.deposit', args: [et.eth(0.5), ctx.wallet3.address], },
//         { from: ctx.wallet3, send: 'enVaults.enTST3.deposit', args: [et.eth(0.5), ctx.wallet3.address], },
//         // wrapped shares set as collateral for the eTST3 debt
//         { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address], },
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.enVaults.enTST3.address], },
//         { send: 'eVaults.eTST3.setLTV', args: [
//             ctx.contracts.enVaults.enTST3.address,
//             Math.floor(0.95 * 1e4),
//             0
//         ], },

//         { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], },

//         { action: 'sendBatch', from: ctx.wallet3, batch: [
//             { send: 'eVaults.eTST3.loop', args: [et.eth(4.5), ctx.wallet3.address] },
//             { send: 'enVaults.enTST3.deposit', args: [et.eth(4.5), et.AddressZero] },
//           ]
//         },


//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue, 4.75, 0.01);
//             et.equals(r.liabilityValue, 4.5);
//         }},

//         { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmFixed', },
//         { action: 'checkpointTime', },

//         { action: 'jumpTimeAndMine', time: 86400 * 225, },
//         { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', },

//         { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet3.address, false], onResult: r => {
//             et.equals(r.collateralValue, '4.7690', '.0001'); // earned a little bit of interest
//             et.equals(r.liabilityValue, '4.7861', '.0001'); // accrued more
//             ctx.stash.hs = r.collateralValue.mul(et.c1e18).div(r.liabilityValue)
//         }},

//         // Liquidate the self collateral

//         { call: 'eVaults.eTST3.checkLiquidation', args: [ctx.wallet.address, ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address],
//           onResult: async r => {
//               ctx.stash.maxRepay = r.maxRepay;
//               ctx.stash.maxYield = r.maxYield;

//               const yieldAssets = await ctx.contracts.eVaults.eTST3.convertToAssets(r.maxYield);
//               const valYield = await ctx.contracts.oracles.priceOracleCore.getQuote(yieldAssets, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               const valRepay = await ctx.contracts.oracles.priceOracleCore.getQuote(r.maxRepay, ctx.contracts.tokens.TST3.address, ctx.contracts.tokens.WETH.address)
//               et.equals(valRepay, valYield.mul(ctx.stash.hs).div(et.c1e18), '0.000000001')
//         }},

//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], equals: 0, },
//         { call: 'enVaults.enTST3.balanceOf', args: [ctx.wallet3.address], onResult: async r => {
//             let assets = await ctx.contracts.eVaults.eTST3.convertToAssets(r)
//             et.equals(assets, '5.0200', '.0001')
//         },},
//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: ['4.7861', '.0001'], onResult: r => ctx.stash.originalDebt = r,},

//         // extra liquidator collateral
//         { send: 'eVaults.eTST.deposit', args: [et.eth(50), ctx.wallet.address], },


//         { send: 'eVaults.eTST3.liquidate', args: [ctx.wallet3.address, ctx.contracts.enVaults.enTST3.address, () => ctx.stash.maxRepay, 0], },

//         { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: () => [ctx.stash.originalDebt.sub(ctx.stash.maxRepay), .001], },
//     ],
// });


// // /*
// // SCF: Self-collateral factor (currently always 0.95)
// // BF: Borrow factor of self-collateralised asset
// // OC: Other collateral: Sum of risk-adjusted asset values *not* including self-collateralised asset (converted to ETH)
// // SA: The self-collateralised asset's *non*-risk adjusted asset value (converted to ETH)
// // SL: The self-collateralised asset's *non*-risk adjusted liability value (converted to ETH)

// // returns M: Max self-collateralised amount (subtract min(SA,SL) to get the additional amount that can be minted)
// // Current leverage: L = (1/(1 - SCF) - 1) * min(SA,SL) / M
// // */

// // function maxSelfCol(SCF, OC, SA, SL) {
// //     return (SA * SCF + OC - SL) / (1 - SCF)
// // }

// // function testSelfColLimit(otherCol, SA, SL) {
// //     ts.test({
// //         desc: `self col limit: OC=${otherCol} / SA=${SA} / SL=${SL}`,
// //         actions: ctx => {
// //             let actions = [];

// //             actions.push({ action: 'setLTV', collateral: 'TST3', liability: 'TST3', cf: 0.95 });

// //             actions.push({ from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], });
// //             actions.push({ from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], });
// //             actions.push({ from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], });

// //             if (otherCol !== 0) actions.push({ from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(otherCol), ctx.wallet3.address], }); 
// //             if (SA !== 0) actions.push({ from: ctx.wallet3, send: 'eVaults.eTST3.deposit', args: [et.eth(SA), ctx.wallet3.address], });
// //             if (SL !== 0) actions.push({ from: ctx.wallet3, send: 'eVaults.eTST3.borrow', args: [et.eth(SL), ctx.wallet3.address], });

// //             let max = maxSelfCol(0.95, otherCol * 0.75 * 0.6, SA, SL);

// //             actions.push({ from: ctx.wallet3, send: 'eVaults.eTST3.loop', args: [et.eth(max + 0.001), ctx.wallet3.address], expectError: 'E_AccountLiquidity', });
// //             actions.push({ from: ctx.wallet3, send: 'eVaults.eTST3.loop', args: [et.eth(max), ctx.wallet3.address], });

// //             return actions;
// //         },
// //     });
// // }

// // testSelfColLimit(5, 0, 0);
// // testSelfColLimit(5, 10, 0);
// // testSelfColLimit(0, 10, 0);
// // testSelfColLimit(5, 10, 5);
// // testSelfColLimit(5, 4, 5);
// // testSelfColLimit(5, 0, 2);



// ts.run();

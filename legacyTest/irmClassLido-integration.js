// const et = require('./lib/eTestLib');

// const A_DAY = 86400
// const A_YEAR = 365.2425 * A_DAY
// const START_BLOCK = 14707000
// const LIDO_SPY_AT_14707000 = et.BN('1270366590784250048')
// const LIDO_SPY_CUSTOM = et.BN('1000000000000000000')
// const MAX_ALLOWED_LIDO_INTEREST_RATE = et.ethers.utils.parseUnits('1', 27).div(A_YEAR) // 100% APY

// const LIDO_ORACLE_ADDRESS = '0x442af784A788A5bd6F42A01Ebe9F287a871243fb'
// const STETH_ADDRESS = '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84'
// const FEE_MANAGER_ADDRESS = '0x2e59a20f205bb85a89c53f1936454680651e618e'

// // storage slot hashes are taken from the github repo
// // https://github.com/lidofinance/lido-dao/blob/master/contracts/0.4.24/oracle/LidoOracle.sol

// const POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION = '0xaa8433b13d2b111d4f84f6f374bc7acbe20794944308876aa250fa9a73dc7f53'
// const PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION = '0x1043177539af09a67d747435df3ff1155a64cd93a347daaac9132a591442d43e'
// const TIME_ELAPSED_POSITION = '0x8fe323f4ecd3bf0497252a90142003855cc5125cee76a5b5ba5d508c7ec28c3a'

// function setLidoOracleStorage(ctx, post, pre, elapsed) {
//     const convertToHexAndPadStart = str => '0x' + et.BN(str).toHexString().slice(2).padStart(64, '0')

//     ctx.setStorageAt(
//         LIDO_ORACLE_ADDRESS, 
//         POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION, 
//         convertToHexAndPadStart(post)
//     )
//     ctx.setStorageAt(
//         LIDO_ORACLE_ADDRESS, 
//         PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION, 
//         convertToHexAndPadStart(pre)
//     )
//     ctx.setStorageAt(
//         LIDO_ORACLE_ADDRESS, 
//         TIME_ELAPSED_POSITION, 
//         convertToHexAndPadStart(elapsed)
//     )
// }

// async function setLidoRewardFee(feePercent) {
//     // due to some reason, setting custom Lido reward by modifying the storage slot directly does not work.
//     // thus, let's get the fee manager address, seed its balance for gas and impersonate the setFee() call
//     await hre.network.provider.send("hardhat_setBalance", [FEE_MANAGER_ADDRESS, '0xfffffffffffffff']);

//     const stETH = new et.ethers.Contract(
//         STETH_ADDRESS, 
//         ['function setFee(uint16) external'], 
//         await et.getImpersonatedSigner(FEE_MANAGER_ADDRESS)
//     )
    
//     await stETH.setFee(feePercent * 100);
// }

// function apy(v) {
//     let apr = Math.log(v + 1);

//     let spy = ethers.BigNumber.from(Math.floor(apr * 1e6))
//               .mul(ethers.BigNumber.from(10).pow(27 - 6))
//               .div(et.SecondsPerYear);

//     return spy;
// }

// function apyInterpolate(apy, frac) {
//     return Math.exp(Math.log(1 + apy) * frac) - 1;
// }

// function repayWithdrawDeposit(ctx) {
//     return [
//         { send: 'eVaults.eUSDT.repay', args: [et.MaxUint25, ctx.wallet.address], },
//         { send: 'eVaults.eUSDT.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
//         { send: 'eVaults.eUSDT.deposit', args: [et.units(100_000, 6), ctx.wallet.address], },
//     ]
// }

// et.testSet({
//     desc: "irm class lido",
//     fixture: 'mainnet-fork',
//     forkAtBlock: START_BLOCK,

//     // the IRM CLASS LIDO model is meant to be used to offset the STETH interest rate.
//     // for this test however, USDT instead for STETH is used as underlying.
//     // for the test to succeed the balace of the underlying token needs to be modified directly in 
//     // the storage (we need to mint tokens for ourselves so we can deposit and borrow them).
//     // as STETH is a rebase token it's not easy to override appropriate storage slots, hence USDT is used
//     preActions: ctx => [
//         { send: 'eVaults.eUSDT.harness_setZeroInterestFee', },
//         { action: 'setInterestRateModel', underlying: 'USDT', irm: 'irmClassLido', },
//         { action: 'setLTV', collateral: 'USDC', liability: 'USDT', cf: 1 },

//         { action: 'setTokenBalanceInStorage', token: 'USDT', for: ctx.wallet.address, amount: 110_000 },
//         { send: 'tokens.USDT.approve', args: [ctx.contracts.eVaults.eUSDT.address, et.MaxUint256], },
//         { send: 'eVaults.eUSDT.deposit', args: [et.units(100_000, 6), ctx.wallet.address], },
//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },

//         { action: 'setTokenBalanceInStorage', token: 'USDC', for: ctx.wallet.address, amount: 210_000 },
//         { send: 'tokens.USDC.approve', args: [ctx.contracts.eVaults.eUSDC.address, et.MaxUint256], },
//         { send: 'eVaults.eUSDC.deposit', args: [et.MaxUint256, ctx.wallet.address], },
//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDC.address], },
//     ],
// })

// .test({
//     desc: "APRs",
//     actions: ctx => [
        
//         // Base=Lido APY,  Kink(80%)=8% APY  Max=200% APY
//         // account for Lido 10% reward fee (fee at block 14707000, can be read from stETH smart contract)

//         // 0% utilisation
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(0), 1e-5], },

//         // very small non-zero utilisation
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [25, ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_AT_14707000.mul(9).div(10), 1e-5], },

//         // 25% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6).sub(25), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_AT_14707000.mul(9).div(10).add(apy(apyInterpolate(.08, 25/80))), 2e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = 1e18
//             setLidoOracleStorage(ctx, '1000500000000000000000000', '1000000000000000000000000', '500000')

//             // jump a bit less as it's not accurate
//             ctx.jumpTime(A_DAY - 50)
//         }},

//         // 80% utilisation, new APY shouldn't be read and stored yet
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(80_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_AT_14707000.mul(9).div(10).add(apy(.08)), 1e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         // jump to pass A_DAY, a bit more as it's not accurate
//         { action: 'jumpTime', time: 100, },

//         // new APY should be read now. A_DAY elapsed, utilisation did not change (still 80%)
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(80_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_CUSTOM.mul(9).div(10).add(apy(.08)), 1e-5], },

//         // 90% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(10_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_CUSTOM.mul(9).div(10).add(apy(2).sub(apy(.08)).div(2).add(apy(.08))), 1e-5], },

//         // 100% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(10_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_CUSTOM.mul(9).div(10).add(apy(2)), 1e-5], },

//         // back to 25% utilisation
//         { send: 'eVaults.eUSDT.repay', args: [et.units(75_000, 6), et.AddressZero], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_CUSTOM.mul(9).div(10).add(apy(apyInterpolate(.08, 25/80))), 2e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = -1e18 
//             // however the negative rebases are not supported hence the offset will be 0
//             setLidoOracleStorage(ctx, '999500000000000000000000', '1000000000000000000000000', '500000')

//             // jump a bit more as it's not accurate
//             ctx.jumpTime(A_DAY + 50)
//         }},

//         // 0% utilisation
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(0), 1e-5], },

//         // 25% utilisation
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(apyInterpolate(.08, 25/80)), 2e-5], },

//         // 80% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(55_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(.08), 1e-5], },

//         // 90% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(10_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(2).sub(apy(.08)).div(2).add(apy(.08)), 1e-5], },

//         // 100% utilisation
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(10_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(2), 1e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = 1e27 which is over the max limit of 100% APY
//             setLidoOracleStorage(ctx, '2', '1', '1')

//             // jump a bit more as it's not accurate
//             ctx.jumpTime(A_DAY + 50)
//         }},

//         // 25% utilisation. the APY should be limited to max 100%
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [MAX_ALLOWED_LIDO_INTEREST_RATE.add(apy(apyInterpolate(.08, 25/80))), 2e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = 0 to avoid div by 0
//             setLidoOracleStorage(ctx, '2', '0', '1')

//             // jump a bit more as it's not accurate
//             ctx.jumpTime(A_DAY + 50)
//         }},

//         // 25% utilisation
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(apyInterpolate(.08, 25/80)), 2e-5], },

//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = 0 to avoid div by 0
//             setLidoOracleStorage(ctx, '2', '1', '0')

//             // jump a bit more as it's not accurate
//             ctx.jumpTime(A_DAY + 50)
//         }},

//         // 25% utilisation
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [apy(apyInterpolate(.08, 25/80)), 2e-5], },

//         // test Lido fee changing
//         // repay, withdraw and deposit again before the time jump not to have utilisation ratio screwed due to interest accrual
//         ...repayWithdrawDeposit(ctx),

//         { action: 'cb', cb: async () => {
//             // SPY = 1e27 * (post - pre) / (pre * elapsed)
//             // the following will correspond to SPY = 1e18
//             setLidoOracleStorage(ctx, '1000500000000000000000000', '1000000000000000000000000', '500000')

//             // set the Lido fee to 20%
//             await setLidoRewardFee(20)

//             // jump a bit more as it's not accurate
//             ctx.jumpTime(A_DAY + 50)
//         }},

//         // 25% utilisation
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eUSDT.address], },
//         { send: 'eVaults.eUSDT.borrow', args: [et.units(25_000, 6), ctx.wallet.address], },
//         { call: 'eVaults.eUSDT.interestRate', args: [], equals: [LIDO_SPY_CUSTOM.mul(8).div(10).add(apy(apyInterpolate(.08, 25/80))), 2e-5], },
//     ],
// })

// .run();

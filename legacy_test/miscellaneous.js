const et = require('./lib/eTestLib');
const child_process = require("child_process");

const hugeAmount = et.eth(9999999999);
const maxSaneAmount = ethers.BigNumber.from(2).pow(112).sub(1);

et.testSet({
    desc: "miscellaneous",

    preActions: ctx => [],
})



.test({
    desc: "get underlying from e/dTokens",
    actions: ctx => [
        { call: 'eVaults.eTST.asset', assertEql: ctx.contracts.tokens.TST.address, },
        { call: 'dTokens.dTST.asset', assertEql: ctx.contracts.tokens.TST.address, },
    ],
})


.test({
    desc: "get price, asset not activated",
    actions: ctx => [
        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST4.address], expectError: 'PO_BaseUnsupported'},
        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST4.address], expectError: 'PO_BaseUnsupported'},
    ],
})


.test({
    desc: "get price of pegged asset",
    actions: ctx => [
        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WETH.address], onResult: r => et.equals(r.currPrice, et.eth(1))},
    ],
})


// TODO test limits of MAX_SANE_AMOUNT now that the small amount is gone
.test({
  desc: "gigantic reserves",
  actions: ctx => [
        { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 },
        // { action: 'setInterestFee', underlying: 'TST', fee: 0.9, },
        { send: 'eVaults.eTST.harness_setInterestFee', args: [60_000 * 0.9] },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet, send: 'tokens.TST.mint', args: [ctx.wallet.address, hugeAmount.mul(10)], },
        { send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], },
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [hugeAmount.mul(10), ctx.wallet.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet, send: 'tokens.TST2.mint', args: [ctx.wallet3.address, hugeAmount.mul(10)], },
        { from: ctx.wallet3, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], },
        { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [hugeAmount.mul(10), ctx.wallet3.address], },
        { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST2.address], },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.borrow', args: [hugeAmount, ctx.wallet3.address], },
        { action: 'checkpointTime', },

        { call: 'eVaults.eTST.totalBorrows', args: [], equals: ['9999999999.0', .1], },

        // dTokens totalSupply is increasing, but is not being stored (totalSupply is a view method):
        { action: 'jumpTimeAndMine', time: 10, },
        { call: 'eVaults.eTST.totalBorrows', args: [], equals: ['10000000316.1', .1], },

        // // But after reserves can no longer be stored, the increase will fail and it is stuck at the stored level:
        // { action: 'jumpTimeAndMine', time: 1000000000, },
        // { call: 'eVaults.eTST.totalBorrows', args: [], equals: ['9999999999.0', .1], },
  ],
})



// TODO
// .test({
//     desc: "decreaseBorrow and transferBorrow more than owed",
//     actions: ctx => [
//         { action: 'installTestModule', id: 100, },
//         { from: ctx.wallet, send: 'tokens.TST.mint', args: [ctx.wallet.address, et.MaxUint256.sub(1)], },
//         { send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], },
//         { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [maxSaneAmount, ctx.wallet.address], expectError: 'E_AmountTooLargeToEncode', },
//         // call path: eVault.deposit > increaseBalance > encodeAmount for user and reserve > amount <= MAX_SANE_AMOUNT
//         // initial deposit reverts because default reserve balance + MAX_SANE_AMOUNT > MAX_SANE_AMOUNT
//         // when we create new market, this line is executed: assetStorage.totalBalances = encodeAmount(INITIAL_RESERVES);
//         { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [maxSaneAmount.sub(et.BN(et.DefaultReserve)), ctx.wallet.address], },
//         // check balance to confirm that user balance decreases by max sane amount
//         { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals: [et.formatUnits(maxSaneAmount), '0.000000000001'], },
//         { call: 'eVaults.eTST.totalSupply', equals: et.formatUnits(maxSaneAmount), },
//         { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
//         { from: ctx.wallet, send: 'tokens.TST2.mint', args: [ctx.wallet3.address, et.MaxUint256.sub(1)], },
//         { from: ctx.wallet3, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], },
//         // the same revert error applies to TST2 market maxSaneAmount deposit
//         { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [maxSaneAmount, ctx.wallet3.address], expectError: 'E_AmountTooLargeToEncode', },
//         { from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [maxSaneAmount.sub(et.BN(et.DefaultReserve)), ctx.wallet3.address], },

//         { from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST2.address], },

//         { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
//         { from: ctx.wallet3, send: 'eVaults.eTST.borrow', args: [et.eth(10), ctx.wallet3.address], },
//         { cb: () => ctx.contracts.testModule.testDecreaseBorrow(ctx.contracts.eVaults.eTST.address, ctx.wallet3.address, et.eth(11)),
//             expectError: 'E_RepayTooMuch', 
//         },

//         { cb: () => ctx.contracts.testModule.testTransferBorrow(ctx.contracts.eVaults.eTST.address, ctx.wallet3.address, ctx.wallet.address, et.eth(11)),
//             expectError: 'E_InsufficientBalance', 
//         },
//     ],
// })




.test({
    desc: "getPrice pool throws other",
    actions: ctx => [
        { send: 'uniswapPools.TST/WETH.mockSetThrowOther', args: [true], },
        { action: 'getPrice', underlying: 'TST', expectError: 'OTHER', },
    ],
})


.test({
    desc: "getPrice pool throws old",
    actions: ctx => [      
        { send: 'uniswapPools.TST/WETH.mockSetThrowOld', args: [true], },
        { action: 'getPrice', underlying: 'TST', expectError: 'OLD', },
    ],
})



.run();

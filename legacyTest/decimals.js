const et = require('./lib/eTestLib');

const debtExact = val => val.mul(et.BN(2).pow(31)).div(et.BN(10).pow(9))
// TST9 has 6 decimals

et.testSet({
    desc: "tokens with non-18 decimals",

    preActions: ctx => {
        let actions = [];

        actions.push({ action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', });

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST9.mint', args: [from.address, et.units('100', 6)], });
            actions.push({ from, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
            actions.push({ from, send: 'evc.enableCollateral', args: [from.address, ctx.contracts.eVaults.eTST2.address], },);
            actions.push({ from, send: 'eVaults.eTST2.deposit', args: [et.eth(50), from.address], });

            // approve TST9 token for repay() to avoid ERC20: transfer amount exceeds allowance error
            actions.push({ from, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], });
        }

        actions.push({ action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '.5', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.2', });

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST9', cf: 0.21})
        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST10', cf: 0.21})

        return actions;
    },
})


.test({
    desc: "basic flow",
    actions: ctx => [
        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST9.address], },
        { action: 'jumpTime', time: 31*60, },
        { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmLinear', },

        { send: 'eVaults.eTST9.deposit', args: [et.units(1, 6), ctx.wallet.address], },
        { call: 'eVaults.eTST9.maxWithdraw', args: [ctx.wallet.address], equals: et.units(1, 6), },
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], assertEql: et.units(1, 6), },
        { call: 'tokens.TST9.balanceOf', args: [ctx.wallet.address], assertEql: et.units(99, 6), },
        { call: 'tokens.TST9.balanceOf', args: [ctx.contracts.eVaults.eTST9.address], assertEql: et.units(1, 6), },

        { send: 'eVaults.eTST9.withdraw', args: [et.units(.2, 6), ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST9.maxWithdraw', args: [ctx.wallet.address], equals: et.units(.8, 6), },
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], equals: et.units(.8, 6), },
        { call: 'tokens.TST9.balanceOf', args: [ctx.wallet.address], assertEql: et.units(99.2, 6), },
        { call: 'tokens.TST9.balanceOf', args: [ctx.contracts.eVaults.eTST9.address], assertEql: et.units(.8, 6), },

        { from: ctx.wallet3, send: 'eVaults.eTST9.borrow', args: [et.units(.3, 6), ctx.wallet3.address], },

        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet3.address], assertEql: et.units(.3, 6), },

        { call: 'eVaults.eTST9.debtOfExact', args: [ctx.wallet3.address], equals: [debtExact(et.units('0.3', 15))], },

        { call: 'eVaults.eTST9.totalBorrows', args: [], assertEql: et.units(.3, 6), },

        { call: 'tokens.TST9.balanceOf', args: [ctx.wallet3.address], assertEql: et.units(.3, 6), },
        { call: 'tokens.TST9.balanceOf', args: [ctx.contracts.eVaults.eTST9.address], assertEql: et.units(.5, 6), },


        // Make sure the TST9 market borrow is recorded
        { call: 'evc.getCollaterals', args: [ctx.wallet3.address],
          assertEql: [ctx.contracts.eVaults.eTST2.address], },
        { call: 'evc.getControllers', args: [ctx.wallet3.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST9.address);
        }, },


        { call: 'eVaults.eTST9.interestAccumulator', args: [], assertEql: et.units(1, 27), },

        { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmFixed', },

        { call: 'eVaults.eTST9.interestAccumulator', args: [], assertEql: et.units('1.000000001188327693544296824', 27), },
        
        // Mint some extra so we can pay interest
        { send: 'tokens.TST9.mint', args: [ctx.wallet3.address, et.units('0.1', 6)], },

        // 1 month later

        { action: 'jumpTime', time: 2628000, }, // 1 month in seconds

        // 1 block later

        { action: 'mineEmptyBlock', },

        { call: 'eVaults.eTST9.debtOfExact', args: [ctx.wallet3.address],  equals: [debtExact(et.units('0.302510442180701', 15)), '0.0000000000000001'], },
        // Rounds up to 6th decimal place:
        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet3.address],      assertEql: et.units('0.302511', 6), },
        // Does round up:
        { call: 'eVaults.eTST9.totalBorrows', args: [],                  assertEql: et.units('0.302511', 6), },

        // Conversion methods
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], equals: [et.units('0.8', 6), et.formatUnits(et.DefaultReserve)], },
        { call: 'eVaults.eTST9.convertToAssets', args: [et.units('0.8', 6)], equals: et.units('0.80086', 6), },
        { call: 'eVaults.eTST9.convertToAssets', args: [et.units('0.8', 6).mul(1000)], equals: [et.units('0.80086', 6).mul(1000), et.units('0.001', 6)] },
        { call: 'eVaults.eTST9.convertToShares', args: [et.units('0.80086', 6)], equals: [et.units('0.8', 6), '.000001'], },

        // Try to pay off full amount:

        { from: ctx.wallet3, send: 'eVaults.eTST9.repay', args: [ et.units('0.302511', 6), ctx.wallet3.address], },

        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet3.address], assertEql: et.units('0', 6), },

        { call: 'eVaults.eTST9.debtOfExact', args: [ctx.wallet3.address], assertEql: 0, },

        // Check if any more interest is accrued after mined block:

        { action: 'mineEmptyBlock' },

        { call: 'eVaults.eTST9.debtOf', args: [ctx.wallet3.address], assertEql: et.units('0', 6), },

        { call: 'eVaults.eTST9.debtOfExact', args: [ctx.wallet3.address], assertEql: et.units('0', 15), },

        { call: 'eVaults.eTST9.totalBorrows', args: [], assertEql: et.units('0', 6), },
        { call: 'eVaults.eTST9.totalBorrowsExact', args: [], assertEql: et.units('0', 6), },
    ],
})


.test({
    desc: "decimals() on e vaults should return same value as underlying",

    actions: ctx => [
        {call: 'tokens.TST9.decimals', args: [], equals: [6] },
        {call: 'eVaults.eTST9.decimals', args: [], equals: [6] },
    ],
})


.test({
    desc: "decimals() on e vaults should always return 18 when underlying decimals is 0",

    actions: ctx => [
        // TST10 has 0 decimals
        { send: 'tokens.TST10.mint', args: [ctx.wallet.address, 100], },
        { send: 'tokens.TST10.approve', args: [ctx.contracts.eVaults.eTST10.address, et.MaxUint256,], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST10.address], },
        { send: 'eVaults.eTST10.deposit', args: [50, ctx.wallet.address] },

        {call: 'tokens.TST10.decimals', args: [], equals: [0] },
        {call: 'eVaults.eTST10.decimals', args: [], equals: [0] },
    ],
})

.test({
    desc: "decimals() on d tokens should always return underlying decimals",

    actions: ctx => [
        // TST9 has 6 decimals
        {call: 'tokens.TST9.decimals', args: [], equals: [6] },
        {call: 'dTokens.dTST9.decimals', args: [], equals: [6] },

        // TST10 has 0 decimals
        { send: 'tokens.TST10.mint', args: [ctx.wallet.address, 100], },
        { send: 'tokens.TST10.approve', args: [ctx.contracts.eVaults.eTST10.address, et.MaxUint256,], },
        { send: 'eVaults.eTST10.deposit', args: [50, ctx.wallet.address] },

        // borrow TST10 with TST2 collateral
        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST10.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST10.borrow', args: [1, ctx.wallet3.address], },

        {call: 'tokens.TST10.decimals', args: [], equals: [0] },
        {call: 'dTokens.dTST10.decimals', args: [], equals: [0] },
    ],
})


.test({
    desc: "no dust left over after max uint redeem",
    actions: ctx => [
        { send: 'eVaults.eTST9.deposit', args: [et.units(1, 6), ctx.wallet.address], },
        { send: 'eVaults.eTST9.withdraw', args: [et.units(.2, 6), ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST9.totalSupply', args: [], equals: et.units('0.8', 6), },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST9.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST9.borrow', args: [et.units(.3, 6), ctx.wallet3.address], },
        { action: 'setInterestRateModel', underlying: 'TST9', irm: 'irmFixed', },
        { send: 'tokens.TST9.mint', args: [ctx.wallet3.address, et.units('0.1', 6)], },


        { action: 'jumpTime', time: 2628000, }, // 1 month in seconds
        { action: 'mineEmptyBlock', },

        { from: ctx.wallet3, send: 'eVaults.eTST9.repay', args: [ et.units('0.302511', 6), ctx.wallet3.address], },

        { send: 'eVaults.eTST9.redeem', args: [et.MaxUint256, ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST9.balanceOf', args: [ctx.wallet.address], assertEql: 0 },
    ],
})


.test({
    desc: "total supply of underlying",
    actions: ctx => [
        { send: 'eVaults.eTST9.deposit', args: [et.units(1.5, 6), ctx.wallet.address], },

        { call: 'eVaults.eTST9.totalSupply', equals: et.units('1.5', 6), },
        { call: 'eVaults.eTST9.totalAssets', equals: et.units('1.5', 6), },
    ],
})

.run();

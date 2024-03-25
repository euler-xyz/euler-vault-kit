const et = require('./lib/eTestLib');

et.testSet({
    desc: "deposit/withdraw balances, with interest",
    preActions: ctx => {
        let actions = [];

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet4]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
            actions.push({ from, send: 'evc.enableCollateral', args: [from.address, ctx.contracts.eVaults.eTST2.address], },);
            actions.push({ from, send: 'evc.enableController', args: [from.address, ctx.contracts.eVaults.eTST.address], },);
            actions.push({ from, send: 'eVaults.eTST2.deposit', args: [et.eth(50), from.address], });
        }

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.1', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.2', });

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.21 });

        actions.push({ action: 'jumpTime', time: 31*60, });

        return actions;
    },
})


.test({
    desc: "basic interest earning flow, no reserves",
    actions: ctx => [
        { send: 'eVaults.eTST.harness_setZeroInterestFee', },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(1), '0.000000000001'], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },
        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(0), },
        { action: 'checkpointTime', },

        { call: 'tokens.TST.balanceOf', args: [ctx.wallet4.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], assertEql: et.eth(1), },

        // Go ahead 1 year (+ 1 second because I did it this way by accident at first, don't want to bother redoing calculations below)

        { action: 'jumpTime', time: 365*86400 + 1, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        // 10% APY interest charged:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], assertEql: et.eth('1.105170921404897917'), },

        // eVault balanceOf unchanged:
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },

        // eVault shares value increases (one less wei than the amount owed):
        { call: 'eVaults.eTST.convertToAssets', args: [et.eth(1)], equals: [et.eth('1.105170921404897916'), '0.00000001'] },


        // Now wallet2 deposits and gets different exchange rate
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(0), },
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], onLogs: logs => {
            logs = logs.filter(l => l.address === ctx.contracts.eVaults.eTST.address);
            et.equals(logs[0].args.value, 0.904, 0.001); // the internal amount
        }},
        { call: 'tokens.TST.balanceOf', args: [ctx.contracts.eVaults.eTST.address], assertEql: et.eth(1), },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], assertEql: et.eth('0.999999999999999999'), },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], equals: [0.904, 0.001], },

        // Go ahead 1 year

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
        { action: 'checkpointTime', },
        { action: 'jumpTime', time: 365*86400, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        // balanceOf calls stay the same

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), onResult: r => ctx.stash.walletBalance = r},
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], equals: [0.904, 0.001], onResult: r => ctx.stash.wallet2Balance = r },
        { call: 'eVaults.eTST.totalSupply', args: [], equals: [1.904, 0.001], },

        // Earnings:
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], assertEql: et.eth('0.999999999999999999') }, // pool utilized
        { send: 'eVaults.eTST.deposit', args: [et.eth(2), ctx.wallet.address], },
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.walletBalance], equals: '1.166190218540982148', },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], equals: '1.05521254310475996', },
        { call: 'eVaults.eTST.totalAssets', args: [], equals: ['4.221402761645908298', '0.000000000000000001'], },

        // More interest is now owed:

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], assertEql: et.eth('1.221402761645908299'), },


        // TODO update values in this comment
        // Additional interest owed = 1.221402761645908299 - 1.105170921404897917 = 0.116231840241010382

        // Total additional earnings: (1.166190218541122110 - 1.105170921404897916) + (1.055212543104786187 - 1) = 0.116231840241010381
        // This matches the additional interest owed (except for the rounding increase)

        // wallet1 has earned more because it started with larger balance. wallet2 should have earned:
        // 0.116231840241010382 / (1 + 1.105170921404897917) = 0.05521254310478618771
        // ... which matches, after truncating to 18 decimals.
    ],
})


.test({
    desc: "basic interest earning flow, with reserves",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], },

        { action: 'setInterestFee', underlying: 'TST', fee: 0.1, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { action: 'checkpointTime', },

        { call: 'eulerLens.doQuery', args: [{ account: et.AddressZero, markets: [ctx.contracts.eVaults.eTST.address], }], onResult: r => {
            let tst = r.markets[0];
            et.equals(tst.borrowAPY, et.units('0.105244346078570209478701625', 27));
            et.equals(tst.supplyAPY, et.units('0.094239711147365655602112334', 27), et.units(et.DefaultReserve, 27));
            // untouchedSupply APY: tst.borrowAPY * .9 = 0.094719911470713188530831462
        }, },

        // Go ahead 1 year, with no reserve credits in between

        { action: 'jumpTime', time: 365.2425 * 86400, },

        { send: 'eVaults.eTST.touch', args: [], onLogs: logs => {
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].name).to.equal('VaultStatus');
            let args = logs[0].args;
            // Compute exchange rate. Matches the maxWithdraw() below, since user has exactly 1 eTST:
            et.equals(args.totalBorrows.mul(et.c1e18).div(args.totalShares), '1.094719911470713189', 0.01);
        }},

        // Interest charged, matches borrowAPY above:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: '1.105244346078570210', },

        // eVault balanceOf unchanged:
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(1), },

        // eVault maxWithdraw increases. 10% less than the amount owed, because of reserve fee. Matches "untouchedSupplyAPY" above:
        { call: 'eVaults.eTST.convertToAssets', args: [et.eth(1)], equals: ['1.094719911470713189', '0.00000001'], },

        // Conversion methods
        { call: 'eVaults.eTST.convertToAssets', args: [et.eth(1)], equals: ['1.094719911470713189', '0.00000001'], },
        { call: 'eVaults.eTST.convertToAssets', args: [et.eth(2)], equals: [et.eth('1.094719911470713189').mul(2), '0.00000001'], },
        { call: 'eVaults.eTST.convertToShares', args: [et.eth('1.094719911470713189')], equals: [et.eth('1'), '0.000000000001'], },
        { call: 'eVaults.eTST.convertToShares', args: [et.eth('1.094719911470713189').div(2)], equals: [et.eth('0.5'), '.000000000001'], },

        // 1.105244346078570210 - 1.094719911470713189 = 0.010524434607857021 // TODO update
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.010524434607856782', '0.000000001'], },


        // Jump another year:

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 365.2425 * 86400, },

        // More interest charged (prev balance * (1+borrowAPY)):
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: '1.221565064538646276', },

        // More interest earned (prev balance * (1+untouchedSupplyAPY)):
        { call: 'eVaults.eTST.convertToAssets', args: [et.eth(1)], equals: ['1.198411684570446122', '0.00000001'], },

        // Original reserve balance times supplyAPY, plus 10% of current interest accrued
        // (0.010524434607857021 * 1.094719911470713188593610243) + (1.221565064538646276 - 1.105244346078570210)*.1 // TODO update
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.023153379968200152', '0.00000001'], },
    ],
})



.test({
    desc: "split interest earning flow, with reserves",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },

        { action: 'setInterestFee', underlying: 'TST', fee: 0.1, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { action: 'checkpointTime', },

        { call: 'eulerLens.doQuery', args: [{ account: et.AddressZero, markets: [ctx.contracts.eVaults.eTST.address], }], onResult: r => {
            let tst = r.markets[0];
            et.equals(tst.borrowAPY, et.units('0.105244346078570209478701625', 27));
            et.equals(tst.supplyAPY, et.units('0.046059133709789858497725776', 27));
            // untouchedSupply APY: (tst.borrowAPY * .9) / 2 = 0.047359955735356594265415731
        }, },

        // Go ahead 1 year
        { action: 'jumpTime', time: 365.2425 * 86400, },
        { send: 'eVaults.eTST.touch', args: [], },

        // Same as in basic case:
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: '1.105244346078570210', },

        // eVault maxWithdraw increases. 10% less than the amount owed, because of reserve fee. Matches untouchedSupplyAPY above:
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], onResult: r => ctx.stash.balance = r},
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.balance], equals: '1.047359955735333033', },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], onResult: r => ctx.stash.balance = r},
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.balance], equals: '1.047359955735333033', },

        // Same as in basic case:

        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.010524434607856782', '0.0000000000000001'], },

        // Get new APYs:

        { call: 'eulerLens.doQuery', args: [{ account: et.AddressZero, markets: [ctx.contracts.eVaults.eTST.address], }], onResult: r => {
            let tst = r.markets[0];
            et.equals(tst.borrowAPY, et.units('0.105244346078570209478701625', 27));
            et.equals(tst.supplyAPY, et.units('0.048416583057772105811320948', 27));
            // untouchedSupplyAPY = 0.049727551487822095990584654
        }, },

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 365.2425 * 86400, },

        // More interest charged (prev balance * (1+borrowAPY)):
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet4.address], equals: '1.221565064538646276', },

        // More interest earned (prev balance * (1+supplyAPY)):

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], onResult: r => ctx.stash.balance = r},
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.balance], equals: '1.099442601860420398', },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet2.address], onResult: r => ctx.stash.balance = r},
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.balance], equals: '1.099442601860420398', },


        // Original reserve balance times supplyAPY, plus 10% of current interest accrued
        // (0.010524434607857021 * 1.049727551487822095990584654) + (1.221565064538646276 - 1.105244346078570210)*.1
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.022679860817706035', '0.0000000000000001'], },
    ],
})



.test({
    desc: "pool-donation is ignored",
    actions: ctx => [
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], },

        { action: 'setInterestFee', underlying: 'TST', fee: 0.1, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },

        { call: 'eulerLens.doQuery', args: [{ account: et.AddressZero, markets: [ctx.contracts.eVaults.eTST.address], }], onResult: r => {
            let tst = r.markets[0];
            et.equals(tst.borrowAPY, et.units('0.105244346078570209478701625', 27));
            et.equals(tst.supplyAPY, et.units('0.094239711147365655602112334', 27), '0.00000001');
        }},

        { from: ctx.wallet2, send: 'tokens.TST.transfer', args: [ctx.contracts.eVaults.eTST.address, et.eth(1)], },
        { action: 'checkpointTime', },

        // no change
        { call: 'eulerLens.doQuery', args: [{ account: et.AddressZero, markets: [ctx.contracts.eVaults.eTST.address], }], onResult: r => {
            let tst = r.markets[0];
            et.equals(tst.borrowAPY, et.units('0.105244346078570209478701625', 27));
            et.equals(tst.supplyAPY, et.units('0.094239711147365655602112334', 27), '0.00000001');
        }},

        // Go ahead 1 year

        { action: 'jumpTime', time: 365.2425 * 86400, },
        { send: 'eVaults.eTST.touch', args: [], },

        // Donation ignored
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], onResult: r => ctx.stash.balance = r},
        { call: 'eVaults.eTST.convertToAssets', args: [() => ctx.stash.balance], equals: ['1.0947199', '0.0000001'], },

        // Reserves still 10%:
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.010524434', '0.0000001'], },
    ],
})



.test({
    desc: "round down internal balance on deposit",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },

        { send: 'eVaults.eTST.harness_setZeroInterestFee', },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { action: 'checkpointTime', },

        // Jump ahead

        { action: 'jumpTime', time: 365*86400*10, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },

        // Exchange rate is ~2.718. Too small, rounded away:
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [1, ctx.wallet.address], expectError: 'E_ZeroShares'},

        // Still too small:
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [2, ctx.wallet.address], expectError: 'E_ZeroShares' },

        // This works:
        { action: 'snapshot', },
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [3, ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1, },
        { action: 'revert', },

        // This works too:
        { action: 'snapshot', },
        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [200, ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 73, }, // floor(200 / 2.718)
        { action: 'revert', },
    ],
})


.test({
    desc: "round up internal balance on withdraw",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },
        { send: 'eVaults.eTST.deposit', args: [2, ctx.wallet.address], },

        { send: 'eVaults.eTST.harness_setZeroInterestFee', },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { action: 'checkpointTime', },

        // Jump ahead

        { action: 'jumpTime', time: 365*86400, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        // Still haven't earned enough interest to actually make any gain:

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 2, },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: '99.999999999999999998', },

        { send: 'eVaults.eTST.withdraw', args: [2, ctx.wallet.address, ctx.wallet.address], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: '100', },
    ],
})



.test({
    desc: "wind/unwind with exchange rate rounding",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet2.address], },
        { send: 'eVaults.eTST.deposit', args: [1, ctx.wallet.address], },

        { send: 'eVaults.eTST.harness_setZeroInterestFee', },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet4.address], },
        { action: 'checkpointTime', },

        // Jump ahead

        { action: 'jumpTime', time: 365*86400*20, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 1, },
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: '99.999999999999999999', },

        { send: 'eVaults.eTST.withdraw', args: [1, ctx.wallet.address, ctx.wallet.address], },

        // Now exchange rate is != 1
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },

        { action: 'snapshot' },

        { send: 'eVaults.eTST.loop', args: [1, ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], onResult: async r => {
            let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
            ctx.stash.bal = assets
        },},
        // debt is rounded up on wind
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], onResult: r => et.expect(r).to.equal(ctx.stash.bal.add(1)), },
        { send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet.address], },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], assertEql: 0, },
        // debt still present
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 1, },
        { call: 'evc.getControllers', args: [ctx.wallet.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
        }, },

        { action: 'revert', },

        // with interest accrued
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'eVaults.eTST.loop', args: [1, ctx.wallet.address], },

        { action: 'checkpointTime', },
        { action: 'jumpTimeAndMine', time: 86400*20, },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], onResult: async r => {
            let assets = await ctx.contracts.eVaults.eTST.convertToAssets(r)
            ctx.stash.bal = assets
        },},
        // debt rounded up
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: () => ctx.stash.bal.add(1).add(1), },

        { send: 'eVaults.eTST.deloop', args: [et.MaxUint256, ctx.wallet.address], },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet.address], assertEql: 2, },
        { call: 'evc.getControllers', args: [ctx.wallet.address], onResult: r => {
            et.expect(r.length).to.equal(1);
            et.expect(r[0]).to.equal(ctx.contracts.eVaults.eTST.address);
        }, },
        { send: 'eVaults.eTST.disableController', expectError: 'E_OutstandingDebt', },
    ],
})


.run();

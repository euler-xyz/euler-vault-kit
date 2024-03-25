const et = require('./lib/eTestLib');

const PROTOCOL_FEE_SHARE = et.eth(0.1)

const protocolShare = fees => et.eth(fees).mul(PROTOCOL_FEE_SHARE).div(et.c1e18);
const riskManagerShare = fees => et.eth(fees).mul(et.c1e18.sub(PROTOCOL_FEE_SHARE)).div(et.c1e18)

et.testSet({
    desc: "reserves",
    preActions: ctx => {
        let actions = [];
        ctx.stash.protocolFeesHolder = ctx.wallet5.address;

        for (let from of [ctx.wallet, ctx.wallet2]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        }

        for (let from of [ctx.wallet3, ctx.wallet4]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
            actions.push({ from, send: 'evc.enableCollateral', args: [from.address, ctx.contracts.eVaults.eTST2.address], },);
            actions.push({ from, send: 'eVaults.eTST2.deposit', args: [et.eth(50), from.address], });
        }

        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 }),

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.1', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.2', });

        actions.push({ action: 'jumpTime', time: 31*60, });

        return actions;
    },
})


.test({
    desc: "reserves",
    actions: ctx => [
        { action: 'setInterestFee', underlying: 'TST', fee: 0.075, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(50), ctx.wallet.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet2.address], },

        { call: 'eVaults.eTST.totalAssets', args: [], equals: et.eth(60), },
        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: 0, },

        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet3.address], },
        { action: 'checkpointTime', },

        { action: 'jumpTimeAndMine', time: 30.5*86400, },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet3.address], equals: ['5.041955', '0.000001'], },

        // 0.041955 * 0.075 = 0.003146625
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.003146', '0.000001'], },

        // After fees: 0.041955 - 0.003146 = 0.038809
        // wallet should get 5/6 of this: 0.03234 (plus original 50)
        // wallet2 should get 1/6 of this: 0.00646 (plus original 10)

        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet.address], equals: ['50.03234', '0.00001'], },
        { call: 'eVaults.eTST.maxWithdraw', args: [ctx.wallet2.address], equals: ['10.00646', '0.00001'], },

        // Some more interest earned:

        { action: 'jumpTimeAndMine', time: 90*86400, },
        { action: 'checkpointTime', },

        { call: 'eVaults.eTST.debtOf', args: [ctx.wallet3.address], equals: ['5.167823', '0.000001'], },

        // 0.167823 * 0.075 = 0.012586
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: ['0.012586', '0.000001'], },

        // Internal units: 0.012554
        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: ['0.012554', '0.000001'], },


        // Now let's try to withdraw some reserves:
        { send: 'eVaults.eTST.setFeeReceiver', args: [ctx.wallet4.address], },
        { send: 'protocolConfig.setFeeReceiver', args: [ctx.stash.protocolFeesHolder], },

        { send: 'eVaults.eTST.convertFees', args: [], },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.stash.protocolFeesHolder], equals: [protocolShare('0.012554'), '0.000001'], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet4.address], equals: [riskManagerShare('0.012554'), '0.000001'], },
        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: 0, },

        // More starts to accrue now:

        { action: 'jumpTimeAndMine', time: 15, },

        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: ['0.000000015', '0.000000001'], },
    ],
})



.test({
    desc: "withdraw without any deposit is a no-op as amount is zero",
    actions: ctx => [
        { action: 'setInterestFee', underlying: 'TST', fee: 0.075, },
        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },

        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: 0, },
        { call: 'eVaults.eTST.accumulatedFeesAssets', args: [], equals: 0, },

        { call: 'eVaults.eTST.totalSupply', args: [], equals: 0, },
        { call: 'eVaults.eTST.totalAssets', args: [], equals: 0, },

        { action: 'checkpointTime', },

        { action: 'jumpTimeAndMine', time: 30.5*86400, },

        { send: 'eVaults.eTST.setFeeReceiver', args: [ctx.wallet4.address], },
        { send: 'protocolConfig.setFeeReceiver', args: [ctx.stash.protocolFeesHolder], },

        { from: ctx.wallet, send: 'eVaults.eTST.convertFees', args: [], onLogs: logs => {
            et.expect(logs.length).to.equal(1);

            // et.expect(logs[0].name).to.equal('Transfer');
            // et.expect(logs[0].args.from).to.equal(et.AddressZero);
            // et.expect(logs[0].args.to).to.equal(ctx.wallet4.address);
            // et.expect(logs[0].args.value).to.equal(0); 

            // et.expect(logs[1].name).to.equal('Deposit');
            // et.expect(logs[1].args.sender).to.equal(et.AddressZero);
            // et.expect(logs[1].args.owner).to.equal(ctx.wallet4.address);
            // et.expect(logs[1].args.assets).to.equal(0); 
            // et.expect(logs[1].args.shares).to.equal(0); 

            // et.expect(logs[2].name).to.equal('Transfer');
            // et.expect(logs[2].args.from).to.equal(et.AddressZero);
            // et.expect(logs[2].args.to).to.equal(ctx.stash.protocolFeesHolder);
            // et.expect(logs[2].args.value).to.equal(0);

            // et.expect(logs[3].name).to.equal('Deposit');
            // et.expect(logs[3].args.sender).to.equal(et.AddressZero);
            // et.expect(logs[3].args.owner).to.equal(ctx.stash.protocolFeesHolder);
            // et.expect(logs[3].args.assets).to.equal(0); 
            // et.expect(logs[3].args.shares).to.equal(0); 

            // et.expect(logs[4].name).to.equal('ConvertFees');
            // et.expect(logs[4].args.protocolReceiver).to.equal(ctx.stash.protocolFeesHolder);
            // et.expect(logs[4].args.feeReceiver).to.equal(ctx.wallet4.address);
            // et.expect(logs[4].args.protocolAssets).to.equal(0);
            // et.expect(logs[4].args.feeAssets).to.equal(0);

            et.expect(logs[0].name).to.equal('VaultStatus');
            et.expect(logs[0].args.accumulatedFees).to.equal(0);
            et.expect(logs[0].args.totalBorrows).to.equal(0);
            et.expect(logs[0].args.totalShares).to.equal(0);
        } },

        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet5.address], equals: 0, },

        { call: 'eVaults.eTST.accumulatedFees', args: [], equals: 0, },
    ],
})


.test({
    desc: "set reserve fee out of bounds",
    actions: ctx => [
        { action: 'setInterestFee', underlying: 'TST', fee: 1.01, expectError: 'E_BadFee', },
    ],
})


// .test({
//     desc: "reserves overflow small amount",
//     actions: ctx => [
//         { action: 'setInterestFee', underlying: 'TST', fee: 0.075, },
//         { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
//         { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '0.000000000000000001', },
//         { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '10000000000', },

//         { from: ctx.wallet, send: 'tokens.TST2.mint', args: [ctx.wallet.address, et.eth('1000000000000000')], },
//         { from: ctx.wallet, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], },
//         { from: ctx.wallet, send: 'eVaults.eTST2.deposit', args: [et.MaxUint256, ctx.wallet.address], },
//         { from: ctx.wallet, send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

//         { from: ctx.wallet, send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
//         { from: ctx.wallet, send: 'eVaults.eTST.loop', args: [et.eth("2594990292056783.4"), ctx.wallet.address], },

//         { action: 'jumpTimeAndMine', time: 30.5*86400, },

//         // Reserves are not updated, because it would've caused E_SmallAmountTooLargeToEncode overflow
//         { call: 'eVaults.eTST.accumulatedFees', args: [], equals: 0, },
//     ],
// })

.run();

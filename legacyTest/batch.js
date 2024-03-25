const { utils } = require('ethers');
const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


et.testSet({
    desc: "batch operations",

    preActions: scenarios.basicLiquidity(),
})




.test({
    desc: "sub-account transfers",
    actions: ctx => [
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: 0, },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 2)], assertEql: 0, },

        { call: 'evc.getCollaterals', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: [], },
        { action: 'setLTV', collateral: 'TST', liability: 'TST2', cf: 0.3 },

        // Do a dry-run
        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(1)], },
              { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 3), et.eth(1)], },
              { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 2), et.eth(.6)], },
              { send: 'evc.enableCollateral', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eTST.address], },
              { send: 'evc.enableController', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eTST2.address], },
              { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST2.borrow', args: [et.eth(1), ctx.wallet.address], },
              { call: 'eVaults.eTST2.accountLiquidityFull', args: [et.getSubAccount(ctx.wallet.address, 1), false]},
              { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 2)]},
              { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 3)]},
          ],
          simulate: true,
          onResult: r => {
            let res  = ctx.contracts.eVaults.eTST.interface.decodeFunctionResult('borrow', r.batchItemsResult[5].result);
            const liquidity = ctx.contracts.eVaults.eTST.interface.decodeFunctionResult('accountLiquidityFull', r.batchItemsResult[6].result);
            et.expect(liquidity.collaterals.length).to.equal(1);
            et.expect(liquidity.collaterals[0]).to.equal(ctx.contracts.eVaults.eTST.address);

            et.equals(liquidity.collateralValues[0], 0.24, .001);
            et.equals(liquidity.liabilityValue, 0.083, .001);

            et.equals(et.BN(r.batchItemsResult[7].result), .6);
            et.equals(et.BN(r.batchItemsResult[8].result), 1);
          },
        },

        // // Do a real one

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(1)], },
              { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST.approve', args: [ctx.wallet.address, et.MaxUint256], },
              { send: 'eVaults.eTST.transferFrom', args: [et.getSubAccount(ctx.wallet.address, 1), et.getSubAccount(ctx.wallet.address, 2), et.eth(.6)], },
              { send: 'evc.enableCollateral', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eTST.address], },
              { send: 'evc.enableController', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eTST2.address], },
              { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST2.borrow', args: [et.eth(1), ctx.wallet.address], },
              { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
              { send: 'eVaults.eTST2.borrow', args: [et.eth(1), ctx.wallet.address], },
          ],
        },

        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: et.eth(.4), },
        { call: 'eVaults.eTST2.debtOf', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: et.eth(1), },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 2)], assertEql: et.eth(.6), },

        { call: 'evc.getCollaterals', args: [et.getSubAccount(ctx.wallet.address, 1)], assertEql: [ctx.contracts.eVaults.eTST.address], },
    ],
})



.test({
    desc: "call to unknown module is permitted",
    actions: ctx => [
        { action: 'sendBatch', batch: [
                { from: ctx.wallet, send: 'tokens.TST.name', args: [] },
          ],
          simulate: true, 
          onResult: r => {
            et.assert(r.batchItemsResult[0].success);
            et.assert(ethers.utils.defaultAbiCoder.decode(['string'], r.batchItemsResult[0].result)[0] === 'Test Token');
          }
        },
    ],
})


.test({
    desc: "batch reentrancy is allowed",
    actions: ctx => [
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: 0, },
        { action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(1)], },
            { send: 'evc.batch', args: [
                [{
                    targetContract: ctx.contracts.eVaults.eTST.address,
                    onBehalfOfAccount: ctx.wallet.address,
                    value: 0,
                    data: ctx.contracts.eVaults.eTST.interface.encodeFunctionData('transfer', [et.getSubAccount(ctx.wallet.address, 1), et.eth(1)])
                }],
            ]}
          ],
        },
        { call: 'eVaults.eTST.balanceOf', args: [et.getSubAccount(ctx.wallet.address, 1)], equals: et.eth(2), },
    ],
})



.test({
    desc: "simulate a batch execution without liquidity checks",
    actions: ctx => [
        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '1'},
        { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '0.4'},
        { action: 'setLTV', collateral: 'TST', liability: 'TST2', cf: 0.3 },
        { action: 'sendBatch', simulate: true, batch: [
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
            { send: 'eVaults.eTST2.borrow', args: [et.eth(10), ctx.wallet.address], },
            { send: 'eVaults.eTST2.accountLiquidity', args: [ctx.wallet.address, false], },
        ], onResult: r => {
            et.expect(r.accountsStatusCheckResult[0].result).to.equal(ctx.contracts.eVaults.eTST2.interface.getSighash('E_AccountLiquidity'));

            const liquidity = ctx.contracts.eVaults.eTST2.interface.decodeFunctionResult('accountLiquidity', r.batchItemsResult[2].result);

            // health score < 1
            et.expect(liquidity.collateralValue.mul(100).div(liquidity.liabilityValue).toString() / 100).to.equal(0.74);
        }},
    ]
})


.test({
    desc: "batch simulation executes all items",
    actions: ctx => [
        { action: 'sendBatch', simulate: true, batch: [
            { send: 'eVaults.eTST2.borrow', args: [et.eth(.1), ctx.wallet.address], },
            { send: 'tokens.TST.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [et.AddressZero, et.AddressZero, et.MaxUint256, 0, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")], },
            { send: 'eVaults.eTST2.borrow', args: [et.eth(.1), ctx.wallet.address], },
        ], onResult: r => {
            et.expect(r.batchItemsResult[1].success).to.equal(false);
            const msg = utils.defaultAbiCoder.decode(["string"], "0x" + r.batchItemsResult[1].result.slice(10))[0];
            et.expect(msg).to.equal("permit: invalid signature")
        }},
    ]
})



.run();

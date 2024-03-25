const et = require('./lib/eTestLib');

const setupLiquidation = ctx => [
    { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmLinear', },
    { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmLinear', },
    { action: 'setInterestRateModel', underlying: 'TST11', irm: 'irmLinear', },

    { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
    { send: 'eVaults.eTST3.borrow', args: [et.eth(29), ctx.wallet.address], },
    { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.5', },
    { call: 'eVaults.eTST3.checkLiquidation', args: [ctx.wallet3.address, ctx.wallet.address, ctx.contracts.eVaults.eTST.address],
        onResult: r => {
            ctx.stash.maxRepay = r.maxRepay;
            ctx.stash.maxYield = r.maxYield;
        },
    },
    { call: 'eVaults.eTST3.accountLiquidity', args: [ctx.wallet.address, false], onResult: r => {
        et.equals(r.collateralValue / r.liabilityValue, 0.5, 0.02);
    }, },

    { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], },
]

const verifyLiquidation = ctx => [
    { from: ctx.wallet3, send: 'eVaults.eTST3.liquidate', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address, () => ctx.stash.maxRepay, 0], },

    // liquidator:
    { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet3.address], equals: () => ctx.stash.maxRepay, },
    { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet3.address], equals: () => [et.eth(1000).add(ctx.stash.maxYield), '0.000001'], },

    // violator:
    { call: 'eVaults.eTST3.debtOf', args: [ctx.wallet.address], equals: async () => [et.eth(29).sub(ctx.stash.maxRepay), '0.1'] },
    { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equals:  () => [et.eth(100).sub(ctx.stash.maxYield), '0.000001'], },
]


et.testSet({
    desc: "malicious token",

    preActions: ctx => {
        let actions = [];

        actions.push({ action: 'setLTV', collateral: 'TST', liability: 'TST3', cf: 0.3 });
        actions.push({ send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ send: 'tokens.TST.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'eVaults.eTST.deposit', args: [et.eth(100), ctx.wallet.address], });
        actions.push({ send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },);

        actions.push({ from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet2, send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(100)], });
        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [et.eth(100), ctx.wallet2.address], });

        actions.push({ from: ctx.wallet3, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet3, send: 'tokens.TST.mint', args: [ctx.wallet3.address, et.eth(1000)], });
        actions.push({ from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(1000), ctx.wallet3.address], });
        actions.push({ from: ctx.wallet3, send: 'evc.enableCollateral', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST.address], },);

        actions.push({ from: ctx.wallet3, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        return actions;
    },
})


.test({
    desc: "transfer returns void",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer/return-void', []], },   
        { send: 'eVaults.eTST.withdraw', args: [et.eth(101), ctx.wallet.address, ctx.wallet.address], expectError: 'E_InsufficientBalance', },
        { send: 'eVaults.eTST.withdraw', args: [et.eth(100), ctx.wallet.address, ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },   
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], equals: et.eth(200), },   
    ],
})


.test({
    desc: "transferFrom returns void",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer-from/return-void', []], },   
        { send: 'eVaults.eTST.deposit', args: [et.eth(100), ctx.wallet.address], },
        { call: 'eVaults.eTST.balanceOf', args: [ctx.wallet.address], equal: et.eth(200), },   
        { call: 'tokens.TST.balanceOf', args: [ctx.wallet.address], assertEql: 0, },   
    ],
})


.test({
    desc: "borrow - transfer reverts",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer/revert', []] },
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], }, 
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(1), ctx.wallet2.address], expectError: 'revert behaviour', },
    ],
})


.test({
    desc: "withdraw - transfer reverts",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer/revert', []] },   
        { send: 'eVaults.eTST.withdraw', args: [et.eth(1), ctx.wallet.address, ctx.wallet.address], expectError: 'revert behaviour', },
    ],
})


.test({
    desc: "repay - transfer from reverts",
    actions: ctx => [
        { from: ctx.wallet3, send: 'evc.enableController', args: [ctx.wallet3.address, ctx.contracts.eVaults.eTST3.address], },
        { from: ctx.wallet3, send: 'eVaults.eTST3.borrow', args: [et.eth(1), ctx.wallet3.address], },
        { send: 'tokens.TST3.mint', args: [ctx.wallet3.address, et.eth(1)], },
        { send: 'tokens.TST3.configure', args: ['transfer-from/revert', []] }, 
        { from: ctx.wallet3, send: 'eVaults.eTST3.repay', args: [et.eth(1), ctx.wallet3.address], expectError: 'TransferFromFailed', },
    ],
})


.test({
    desc: "deposit - transfer from reverts",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer-from/revert', []] }, 
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], expectError: 'TransferFromFailed', },
    ],
})



.test({
    desc: "deposit - transfer from reenters",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer-from/call', et.abiEncode(
            ['address', 'bytes'],
            [
                ctx.contracts.eVaults.eTST.address,
                ctx.contracts.eVaults.eTST.interface.encodeFunctionData('withdraw', [et.eth(1), ctx.wallet.address, ctx.wallet.address]),
            ]
        )]}, 
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], expectError: 'E_Reentrancy', },
    ],
})


.test({
    desc: "deposit - transfer from reenters view method",
    actions: ctx => [
        { send: 'tokens.TST.configure', args: ['transfer-from/call', et.abiEncode(
            ['address', 'bytes'],
            [
                ctx.contracts.eVaults.eTST.address,
                ctx.contracts.eVaults.eTST.interface.encodeFunctionData('maxWithdraw', [ctx.wallet.address]),
            ]
        )]},
        { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], expectError: 'E_Reentrancy', },
    ],
})


.test({
    desc: "can liquidate - transfer reverts",
    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['transfer/revert', []], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - transfer from reverts",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['transfer-from/revert', []], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - balance of consumes all gas",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['balance-of/consume-all-gas', []], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - balance of returns max uint",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['balance-of/set-amount', et.abiEncode(['uint256'], [et.MaxUint256])], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - balance of returns 0",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['balance-of/set-amount', et.abiEncode(['uint256'], [0])], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - balance of reverts",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['balance-of/revert', []], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - balance of panics",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.configure', args: ['balance-of/panic', []], },
        ...verifyLiquidation(ctx),
    ],
})


.test({
    desc: "can liquidate - self destruct",

    actions: ctx => [
        ...setupLiquidation(ctx),
        { send: 'tokens.TST3.callSelfDestruct', },
        ...verifyLiquidation(ctx),
    ],
})



// .test({
//     desc: "deflationary - deposit, borrow, burn repay, withdraw",
//     actions: ctx => [
//         { action: 'setInterestRateModel', underlying: 'TST11', irm: 'irmZero', },
//         { send: 'tokens.TST11.configure', args: ['transfer/deflationary', et.abiEncode(['uint256'], [et.eth(1)])], },

//         { from: ctx.wallet2, send: 'tokens.TST11.approve', args: [ctx.contracts.eVaults.eTST11.address, et.MaxUint256,], },
//         { from: ctx.wallet2, send: 'tokens.TST11.mint', args: [ctx.wallet2.address, et.eth(10)], },
//         { from: ctx.wallet2, send: 'eVaults.eTST11.deposit', args: [et.eth(10), ctx.wallet2.address], },
//         { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST11.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.contracts.eVaults.eTST11.address], assertEql: et.eth(9), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(9), },

//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST11.address], },
//         { send: 'eVaults.eTST11.borrow', args: [et.eth(5), ctx.wallet.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(4), },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: et.eth(5), },

//         { send: 'tokens.TST11.approve', args: [ctx.contracts.eVaults.eTST11.address, et.MaxUint256,], },
//         { send: 'eVaults.eTST11.repay', args: [et.eth(4), et.AddressZero], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet.address], assertEql: 0, },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: et.eth(2), },

//         { send: 'tokens.TST11.mint', args: [ctx.wallet.address, et.eth(3)], },
//         { send: 'eVaults.eTST11.deposit', args: [et.eth(3), ctx.wallet.address], },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: et.eth(2), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet.address], equals: et.eth(2), },
//         { call: 'eVaults.eTST11.maxWithdraw', args: [ctx.wallet.address], assertEql: et.eth(2), },

//         { send: 'tokens.TST11.mint', args: [ctx.wallet.address, et.eth(2)], },
//         { send: 'eVaults.eTST11.deposit', args: [et.eth(2), ctx.wallet.address], },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet.address], equals: et.eth(3), },
//         { call: 'eVaults.eTST11.maxWithdraw', args: [ctx.wallet.address], assertEql: et.eth(3), },
//         { send: 'eVaults.eTST11.deloop', args: [et.eth(2), ctx.wallet.address], },

//         { call: 'tokens.TST11.balanceOf', args: [ctx.contracts.eVaults.eTST11.address], assertEql: et.eth(10), },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: et.eth(0), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet.address], equals: et.eth(1), },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(0), },

//         { from: ctx.wallet2, send: 'eVaults.eTST11.withdraw', args: [et.eth(9).add(1), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_InsufficientBalance', },
//         { from: ctx.wallet2, send: 'eVaults.eTST11.withdraw', args: [et.eth(8), ctx.wallet2.address, ctx.wallet2.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.contracts.eVaults.eTST11.address], assertEql: et.eth(2), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet2.address], equals: et.eth(1), },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(7), },
//     ],
// })


// .test({
//     desc: "inflationary - deposit, borrow, repay, withdraw",
//     actions: ctx => [
//         { action: 'setInterestRateModel', underlying: 'TST11', irm: 'irmZero', },
//         { send: 'tokens.TST11.configure', args: ['transfer/inflationary', et.abiEncode(['uint256'], [et.eth(1)])], },

//         { from: ctx.wallet2, send: 'tokens.TST11.approve', args: [ctx.contracts.eVaults.eTST11.address, et.MaxUint256,], },
//         { from: ctx.wallet2, send: 'tokens.TST11.mint', args: [ctx.wallet2.address, et.eth(10)], },
//         { from: ctx.wallet2, send: 'eVaults.eTST11.deposit', args: [et.eth(10), ctx.wallet2.address], },
//         { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST11.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.contracts.eVaults.eTST11.address], assertEql: et.eth(11), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(11), },

//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST11.address], },
//         { send: 'eVaults.eTST11.borrow', args: [et.eth(5), ctx.wallet.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(6), },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: et.eth(5), },

//         { send: 'tokens.TST11.approve', args: [ctx.contracts.eVaults.eTST11.address, et.MaxUint256,], },
//         { send: 'eVaults.eTST11.repay', args: [et.eth(4), et.AddressZero], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet.address], assertEql: et.eth(2), },
//         { call: 'eVaults.eTST11.debtOf', args: [ctx.wallet.address], assertEql: 0, },

//         { from: ctx.wallet2, send: 'eVaults.eTST11.withdraw', args: [et.eth(11).add(1), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_InsufficientCash', },
//         { from: ctx.wallet2, send: 'eVaults.eTST11.withdraw', args: [et.eth(10), ctx.wallet2.address, ctx.wallet2.address], },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.contracts.eVaults.eTST11.address], assertEql: et.eth(1), },
//         { call: 'eVaults.eTST11.balanceOf', args: [ctx.wallet2.address], equals: et.eth(1), },
//         { call: 'tokens.TST11.balanceOf', args: [ctx.wallet2.address], assertEql: et.eth(11), },
//     ],
// })

.run();

const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');

const OP_DEPOSIT = 1 << 0;
const OP_MINT = 1 << 1;
const OP_WITHDRAW = 1 << 2;
const OP_REDEEM = 1 << 3;
const OP_TRANSFER = 1 << 4;
const OP_SKIM = 1 << 5;
const OP_BORROW = 1 << 6;
const OP_REPAY = 1 << 7;
const OP_LOOP = 1 << 8;
const OP_DELOOP = 1 << 9;
const OP_PULL_DEBT = 1 << 10;
const OP_CONVERT_FEES = 1 << 11;
const OP_LIQUIDATE = 1 << 12;
const OP_FLASHLOAN = 1 << 13;
const OP_TOUCH = 1 << 14;

const MAX_SANE_AMOUNT = et.BN(2).pow(112).sub(1);

et.testSet({
    desc: "market policies",
    preActions: ctx => {
        let actions = scenarios.basicLiquidity()(ctx)

        actions.push({ send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eTST3.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 1 });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '.01', })

        actions.push({ send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], })
        actions.push({ send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], })

        return actions
    }
})

.test({
    desc: "simple supply cap - deposit",
    actions: ctx => [
        { call: 'eVaults.eTST.cash', equals: [10, .001], },
        { call: 'eVaults.eTST.maxDeposit', args: [ctx.wallet.address], equals: MAX_SANE_AMOUNT.sub(et.eth(10)), },
        { call: 'eVaults.eTST.maxMint', args: [ctx.wallet.address], equals: MAX_SANE_AMOUNT.sub(et.eth(10)), },

        // Deposit prevented:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 11, }, },
        { call: 'eVaults.eTST.maxDeposit', args: [ctx.wallet.address], equals: et.eth(1), },
        { call: 'eVaults.eTST.maxMint', args: [ctx.wallet.address], equals: et.eth(1), },
        { send: 'eVaults.eTST.deposit', args: [et.eth(2), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },
        
        // Raise Cap and it succeeds:
        
        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 13, }, },
        { call: 'eVaults.eTST.maxDeposit', args: [ctx.wallet.address], equals: et.eth(3), },
        { send: 'eVaults.eTST.deposit', args: [et.eth(2), ctx.wallet.address], },

        // New limit prevents additional deposits:

        { send: 'eVaults.eTST.deposit', args: [et.eth(2), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

        // Lower supply cap. Withdrawal still works, even though it's not enough withdrawn to solve the policy violation:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 5, }, },
        { call: 'eVaults.eTST.maxDeposit', args: [ctx.wallet.address], equals: 0, },
        { call: 'eVaults.eTST.maxMint', args: [ctx.wallet.address], equals: 0, },
        { send: 'eVaults.eTST.withdraw', args: [et.eth(3), ctx.wallet.address, ctx.wallet.address], },

        { call: 'eVaults.eTST.totalSupply', equals: [9, .001], },

        // Deposit doesn't work

        { send: 'eVaults.eTST.deposit', args: [et.eth(.1), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },
    ],
})

.test({
    desc: "simple supply cap - mint",
    actions: ctx => [
        { call: 'eVaults.eTST.totalSupply', equals: [10, .001], },

        // Mint prevented:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 11, }, },
        { send: 'eVaults.eTST.mint', args: [et.eth(2), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

        // Raise Cap and it succeeds:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 13, }, },
        { send: 'eVaults.eTST.mint', args: [et.eth(2), ctx.wallet.address], },

        // New limit prevents additional minting:

        { send: 'eVaults.eTST.mint', args: [et.eth(2), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

        // Lower supply cap. Withdrawal still works, even though it's not enough withdrawn to solve the policy violation:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 5, }, },
        { send: 'eVaults.eTST.withdraw', args: [et.eth(3), ctx.wallet.address, ctx.wallet.address], },

        { call: 'eVaults.eTST.totalSupply', equals: [9, .001], },

        // Mint doesn't work

        { send: 'eVaults.eTST.mint', args: [et.eth(.1), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },
    ],
})


.test({
    desc: "simple borrow cap",
    actions: ctx => [
        { send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet.address], },

        { call: 'eVaults.eTST.totalBorrows', equals: [5, .001], },

        // Borrow prevented:

        { action: 'setCaps', tok: 'TST', caps: { borrowCap: 6, }, },
        { send: 'eVaults.eTST.borrow', args: [et.eth(2), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },

        // Raise Cap and it succeeds:

        { action: 'setCaps', tok: 'TST', caps: { borrowCap: 8, }, },
        { send: 'eVaults.eTST.borrow', args: [et.eth(2), ctx.wallet.address], },

        // New limit prevents additional borrows:

        { send: 'eVaults.eTST.borrow', args: [et.eth(2), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },

        // Jump time so that new total borrow exceeds the borrow cap due to the interest accrued

        { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmFixed', },
        { call: 'eVaults.eTST.totalBorrows', equals: [7, .001], },

        { action: 'jumpTimeAndMine', time: 2 * 365 * 24 * 60 * 60, },   // 2 years
        { call: 'eVaults.eTST.totalBorrows', equals: [8.55, .001], },

        // Touch still works, updating total borrows in storage

        { send: 'eVaults.eTST.touch', },
        { call: 'eVaults.eTST.totalBorrows', equals: [8.55, .001], },

        // Repay still works, even though it's not enough repaid to solve the policy violation:

        { send: 'eVaults.eTST.repay', args: [et.eth(0.15), ctx.wallet.address], },

        { call: 'eVaults.eTST.totalBorrows', equals: [8.4, .001], },

        // Borrow doesn't work

        { send: 'eVaults.eTST.borrow', args: [et.eth(.1), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },
    ],
})


.test({
    desc: "supply and borrow cap for wind",
    actions: ctx => [
        { call: 'eVaults.eTST.totalSupply', equals: [10, .001], },
        { call: 'eVaults.eTST.totalBorrows', equals: [0], },

        // Wind prevented:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 12, borrowCap: 5 }, },
        { send: 'eVaults.eTST.loop', args: [et.eth(3), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

        // Wind prevented:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 15, borrowCap: 2 }, },
        { send: 'eVaults.eTST.loop', args: [et.eth(3), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },

        // Raise caps and it succeeds:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 15, borrowCap: 5 }, },
        { send: 'eVaults.eTST.loop', args: [et.eth(3), ctx.wallet.address], },

        // New limit prevents additional mints:

        { send: 'eVaults.eTST.loop', args: [et.eth(3), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },

        // Lower supply cap. Unwind still works, even though it's not enough burnt to solve the policy violation:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 1, borrowCap: 1 }, },
        { send: 'eVaults.eTST.deloop', args: [et.eth(1), ctx.wallet.address], },
        { call: 'eVaults.eTST.totalSupply', equals: [12, .001], },
        { call: 'eVaults.eTST.totalBorrows', equals: [2, .001], },

        // Deposit doesn't work

        { send: 'eVaults.eTST.loop', args: [et.eth(.1), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },

        // Turn off supply cap. Wind still doesn't work because of borrow cap

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 1, borrowCap: 0 }, },
        { send: 'eVaults.eTST.loop', args: [et.eth(.1), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },
    ],
})


.test({
    desc: "deferral of supply cap check",
    actions: ctx => [
        // Current supply 10, supply cap 15

        { call: 'eVaults.eTST.totalSupply', equals: [10, .001], },
        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 15, }, },

        // Deferring doesn't allow us to leave the asset in policy violation:

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], },
          ],
          expectError: 'E_SupplyCapExceeded',
        },

        { action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.mint', args: [et.eth(10), ctx.wallet.address], },
        ],
        expectError: 'E_SupplyCapExceeded',
      },

        // Transient violations don't fail the batch:

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], },
              { send: 'eVaults.eTST.withdraw', args: [et.eth(8), ctx.wallet.address, ctx.wallet.address], },
          ],
        },

        { action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.mint', args: [et.eth(10), ctx.wallet.address], },
            { send: 'eVaults.eTST.redeem', args: [et.eth(8), ctx.wallet.address, ctx.wallet.address], },
          ],
        },

        { call: 'eVaults.eTST.totalSupply', equals: [14, .001], },
    ],
})


.test({
    desc: "deferral of borrow cap check",
    actions: ctx => [
        // Current borrow 0, borrow cap 5

        { call: 'eVaults.eTST.totalBorrows', equals: [0, .001], },
        { action: 'setCaps', tok: 'TST', caps: { borrowCap: 5, }, },

        // Deferring doesn't allow us to leave the asset in policy violation:

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.borrow', args: [et.eth(6), ctx.wallet.address], },
          ],
          expectError: 'E_BorrowCapExceeded',
        },

        // Transient violations don't fail the batch:

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.borrow', args: [et.eth(6), ctx.wallet.address], },
              { send: 'eVaults.eTST.repay', args: [et.eth(2), ctx.wallet.address], },
          ],
        },

        { call: 'eVaults.eTST.totalBorrows', equals: [4, .001], },
    ],
})


.test({
    desc: "simple operations pausing",
    actions: ctx => [
        // Deposit prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_DEPOSIT], },
        { send: 'eVaults.eTST.deposit', args: [5, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.deposit', args: [5, ctx.wallet.address], },

        // Mint prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_MINT], },
        { send: 'eVaults.eTST.mint', args: [5, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.mint', args: [5, ctx.wallet.address], },

        // Withdrawal prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_WITHDRAW], },
        { send: 'eVaults.eTST.withdraw', args: [5, ctx.wallet.address, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.withdraw', args: [5, ctx.wallet.address, ctx.wallet.address], },

        // Redeem prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_REDEEM], },
        { send: 'eVaults.eTST.redeem', args: [5, ctx.wallet.address, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.redeem', args: [5, ctx.wallet.address, ctx.wallet.address], },

        // Wind prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_LOOP], },
        { send: 'eVaults.eTST.loop', args: [5, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.loop', args: [5, ctx.wallet.address], },

        // Unwind prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_DELOOP], },
        { send: 'eVaults.eTST.deloop', args: [5, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.deloop', args: [5, ctx.wallet.address], },

        // setup

        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },

        // Borrow prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_BORROW], },
        { send: 'eVaults.eTST.borrow', args: [5, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.borrow', args: [5, ctx.wallet.address], },

        { send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet.address], },

        // Repay prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_REPAY], },
        { send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet.address], },

        // eVault transfer prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_TRANSFER], },
        { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(5)], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { send: 'eVaults.eTST.transfer', args: [et.getSubAccount(ctx.wallet.address, 1), et.eth(5)], },

        // setup
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], },
        { send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet.address], },

        // Debt transfer prevented:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, OP_PULL_DEBT], },
        { from: ctx.wallet2, send: 'eVaults.eTST.pullDebt', args: [et.eth(1), ctx.wallet.address], expectError: 'E_OperationDisabled', },

        // Remove pause and it succeeds:

        { send: 'eVaults.eTST.setHookConfig', args: [et.AddressZero, 0], },
        { from: ctx.wallet2, send: 'eVaults.eTST.pullDebt', args: [et.eth(1), ctx.wallet.address], },

        // TODO other operations
    ],
})


.test({
    desc: "complex scenario",
    actions: ctx => [
        { action: 'setLTV', collateral: 'TST', liability: 'TST2', cf: 1 },
        { action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.01', }, 

        { call: 'eVaults.eTST.totalSupply', equals: [10, .001], },
        { call: 'eVaults.eTST2.totalSupply', equals: [10, .001], },
        { call: 'eVaults.eTST.totalBorrows', equals: [0], },
        { call: 'eVaults.eTST2.totalBorrows', equals: [0], },

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 15, }, },
        { action: 'setCaps', tok: 'TST2', caps: { borrowCap: 5, }, },
        { send: 'eVaults.eTST2.setHookConfig', args: [et.AddressZero, OP_LOOP], },

        // This won't work because the end state violates market policies:

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.disableController', },
              { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

              { send: 'eVaults.eTST.deposit', args: [et.eth(7), ctx.wallet.address], },
              { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },

              { send: 'eVaults.eTST.withdraw', args: [et.eth(1), ctx.wallet.address, ctx.wallet.address], },
              { send: 'eVaults.eTST2.repay', args: [et.eth(3), ctx.wallet.address], },
          ],
          expectError: 'E_SupplyCapExceeded',
        },

        { action: 'sendBatch', batch: [
              { send: 'eVaults.eTST.disableController', },
              { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

              { send: 'eVaults.eTST.deposit', args: [et.eth(7), ctx.wallet.address], },
              { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },

              { send: 'eVaults.eTST.withdraw', args: [et.eth(3), ctx.wallet.address, ctx.wallet.address], },
              { send: 'eVaults.eTST2.repay', args: [et.eth(1), ctx.wallet.address], },
        ],
          expectError: 'E_BorrowCapExceeded',
        },

        // Succeeeds if there's no violation:

        { action: 'sendBatch', batch: [
            { send: 'eVaults.eTST.disableController', },
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

            { send: 'eVaults.eTST.deposit', args: [et.eth(7), ctx.wallet.address], },
            { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },

            { send: 'eVaults.eTST.withdraw', args: [et.eth(3), ctx.wallet.address, ctx.wallet.address], },
            { send: 'eVaults.eTST2.repay', args: [et.eth(3), ctx.wallet.address], },
        ]},


        { send: 'eVaults.eTST.withdraw', args: [et.eth(4), ctx.wallet.address, ctx.wallet.address], },
        { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet.address], },
        // Fails again if wind item added:
        { send: 'eVaults.eTST.disableController', },

        { action: 'sendBatch', batch: [
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

            { send: 'eVaults.eTST.deposit', args: [et.eth(7), ctx.wallet.address], },
            { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },

            { send: 'eVaults.eTST2.loop', args: [et.eth(0), ctx.wallet.address], },

            { send: 'eVaults.eTST.withdraw', args: [et.eth(3), ctx.wallet.address, ctx.wallet.address], },
            { send: 'eVaults.eTST2.repay', args: [et.eth(3), ctx.wallet.address], },
        ],
          expectError: 'E_OperationDisabled',
        },

        // Succeeds if wind item added for TST instead of TST2:

        { action: 'sendBatch', batch: [
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },

            { send: 'eVaults.eTST.deposit', args: [et.eth(7), ctx.wallet.address], },
            { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },

            { send: 'eVaults.eTST.loop', args: [et.eth(1), ctx.wallet.address], },

            { send: 'eVaults.eTST.withdraw', args: [et.eth(4), ctx.wallet.address, ctx.wallet.address], },
            { send: 'eVaults.eTST2.repay', args: [et.MaxUint256, ctx.wallet.address], },

            { send: 'eVaults.eTST.repay', args: [et.MaxUint256, ctx.wallet.address], },
            { send: 'eVaults.eTST.disableController', },
        ]},

        // checkpoint:

        { call: 'eVaults.eTST.totalSupply', equals: [14, .001], },
        { call: 'eVaults.eTST2.totalSupply', equals: [10, .001], },
        { call: 'eVaults.eTST.totalBorrows', equals: [0], },
        { call: 'eVaults.eTST2.totalBorrows', equals: [0, .001], },

        // set new market policies:

        { action: 'setCaps', tok: 'TST', caps: { supplyCap: 10, borrowCap: 1 }, },
        { action: 'setCaps', tok: 'TST2', caps: { supplyCap: 1, borrowCap: 1, }, },

        { action: 'sendBatch', batch: [
            { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
            { send: 'evc.enableController', args: [et.getSubAccount(ctx.wallet.address, 1), ctx.contracts.eVaults.eTST2.address], },

            { send: 'eVaults.eTST2.borrow', args: [et.eth(7), ctx.wallet.address], },   // this exceeds the borrow cap temporarily
            { send: 'eVaults.eTST2.deposit', args: [et.MaxUint256, et.getSubAccount(ctx.wallet.address, 1)], },   // this exceeds the supply cap temporarily

            { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST2.pullDebt', args: [et.MaxUint256, ctx.wallet.address], }, // this exceeds the borrow cap temporarily
            
            { send: 'eVaults.eTST.deposit', args: [et.eth(1), ctx.wallet.address], },    // this exceeds the supply cap temporarily

            // this should unwind TST2 debt and deposits, leaving the TST2 borrow cap no longer violated
            // TST2 supply cap is not an issue, although exceeded, total balances stayed the same within the transaction
            { from: et.getSubAccount(ctx.wallet.address, 1), send: 'eVaults.eTST2.deloop', args: [et.MaxUint256, et.getSubAccount(ctx.wallet.address, 1)], },

            // this should withdraw more TST than deposited, leaving the TST supply cap no longer violated
            { send: 'eVaults.eTST.withdraw', args: [et.eth(2), ctx.wallet.address, ctx.wallet.address], },
        ]},

        { call: 'eVaults.eTST.totalSupply', equals: [13, .001], },
        { call: 'eVaults.eTST2.totalSupply', equals: [10, .001], },
        { call: 'eVaults.eTST.totalBorrows', equals: [0], },
        { call: 'eVaults.eTST2.totalBorrows', equals: [0, .001], },
    ],
})


// .test({
//     desc: "supply/borrow caps, 6 decimals",
//     actions: ctx => [
//         { action: 'setLTV', collateral: 'TST', liability: 'TST9', cf: 1 },
//         { action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '.00000001', },

//         { send: 'tokens.TST9.mint', args: [ctx.wallet.address, et.units(2e6, 6)], },
//         { send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], },

//         { send: 'eVaults.eTST.disableController', },
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST9.address], },

//         // Deposit prevented:

//         { action: 'setMarketPolicy', tok: 'TST9', policy: { supplyCap: 1e6, }, },
//         { send: 'eVaults.eTST9.deposit', args: [et.units('1000000', 6), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

//         // Raise Cap and it succeeds:

//         { action: 'setMarketPolicy', tok: 'TST9', policy: { supplyCap: 1.1e6, }, },
//         { send: 'eVaults.eTST9.deposit', args: [et.units('1000000', 6), ctx.wallet.address], },

//         // Set a borrow cap

//         { action: 'setMarketPolicy', tok: 'TST9', policy: { supplyCap: 1.1e6, borrowCap: 0.5e6, }, },
//         { send: 'eVaults.eTST9.borrow', args: [et.units(0.4e6, 6), ctx.wallet.address], },
//         { send: 'eVaults.eTST9.borrow', args: [et.units(0.2e6, 6), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },
//     ],
// })


// .test({
//     desc: "supply/borrow caps, 0 decimals",
//     actions: ctx => [
//         { action: 'setLTV', collateral: 'TST', liability: 'TST10', cf: 1 },
//         { action: 'updateUniswapPrice', pair: 'TST10/WETH', price: '.00000001', },

//         { send: 'tokens.TST10.mint', args: [ctx.wallet.address, et.units(100000, 0)], },
//         { send: 'tokens.TST10.approve', args: [ctx.contracts.eVaults.eTST10.address, et.MaxUint256,], },

//         { send: 'eVaults.eTST.disableController', },
//         { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST10.address], },

//         // Deposit prevented:

//         { action: 'setMarketPolicy', tok: 'TST10', policy: { supplyCap: 8000, }, },
//         { send: 'eVaults.eTST10.deposit', args: [et.units(8000, 0), ctx.wallet.address], expectError: 'E_SupplyCapExceeded', },

//         // Raise Cap and it succeeds:

//         { action: 'setMarketPolicy', tok: 'TST10', policy: { supplyCap: 8001, }, },
//         { send: 'eVaults.eTST10.deposit', args: [et.units(8000, 0), ctx.wallet.address], },

//         // Set a borrow cap

//         { action: 'setMarketPolicy', tok: 'TST10', policy: { supplyCap: 8001, borrowCap: 2000, }, },
//         { send: 'eVaults.eTST10.borrow', args: [et.units(1999, 0), ctx.wallet.address], },
//         { send: 'eVaults.eTST10.borrow', args: [et.units(1, 0), ctx.wallet.address], expectError: 'E_BorrowCapExceeded', },
//     ],
// })



.run();
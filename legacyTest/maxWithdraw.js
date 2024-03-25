const et = require('./lib/eTestLib');

const DEFAULT_LIQUIDATION_FEE = et.eth(0.02)
const NO_EXPIRY = et.BN(2).pow(40).sub(2)

const getRepayPreFees = (ctx, amount) => {
    return amount.mul(et.eth(1)).mul(et.eth(1)).div(et.eth(1).add(DEFAULT_LIQUIDATION_FEE)).div(et.eth(1))
}
const getRiskAdjustedValue = (amount, price, factor) => amount.mul(et.eth(price)).div(et.eth(1)).mul(et.eth(factor)).div(et.eth(1))

et.testSet({
    desc: "max withdraw",

    preActions: ctx => {
        let actions = [];

        actions.push({ action: 'setInterestRateModel', underlying: 'WETH', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', });
        actions.push({ action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', });
        actions.push({ action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 }),
        // wallet is lender and liquidator

        actions.push({ send: 'tokens.TST.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eTST.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ send: 'tokens.WETH.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.WETH.approve', args: [ctx.contracts.eVaults.eWETH.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eWETH.deposit', args: [et.eth(100), ctx.wallet.address], });

        actions.push({ send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(200)], });
        actions.push({ send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], });
        actions.push({ send: 'eVaults.eTST3.deposit', args: [et.eth(100), ctx.wallet.address], });

        // wallet2 is borrower/violator

        actions.push({ send: 'tokens.TST2.mint', args: [ctx.wallet2.address, et.eth(100)], });
        actions.push({ from: ctx.wallet2, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(100), ctx.wallet2.address], });
        actions.push({ from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST2.address], },);

        // wallet3 is innocent bystander

        actions.push({ send: 'tokens.TST.mint', args: [ctx.wallet3.address, et.eth(100)], });
        actions.push({ from: ctx.wallet3, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet3, send: 'eVaults.eTST.deposit', args: [et.eth(30), ctx.wallet3.address], });
        actions.push({ send: 'tokens.TST2.mint', args: [ctx.wallet3.address, et.eth(100)], });
        actions.push({ from: ctx.wallet3, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });
        actions.push({ from: ctx.wallet3, send: 'eVaults.eTST2.deposit', args: [et.eth(18), ctx.wallet3.address], });

        // initial prices

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.2', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '.4', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '2.2', });

        return actions;
    },
})




.test({
    desc: "can't withdraw deposit not entered as collateral when account unhealthy",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
        }, },

        // depositing but not entering collateral
        { send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(10)], },
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
        { from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [et.eth(1), ctx.wallet2.address]},

        // account unhealthy
        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.96, 0.001);
        }, },

        { from: ctx.wallet2, send: 'eVaults.eTST3.withdraw', args: [et.eth(1), ctx.wallet2.address, ctx.wallet2.address], expectError: 'E_AccountLiquidity', },
    ]
})


.test({
    desc: "max withdraw with borrow",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
        }, },


        { action: 'snapshot'},
            { call: 'eVaults.eTST2.maxRedeem', args: [ctx.wallet2.address], onResult: r => {
                ctx.stash.maxRedeem = r
                et.equals(r, '8.33638821674561256')
            }},
            { call: 'eVaults.eTST2.maxWithdraw', args: [ctx.wallet2.address], onResult: r => {
                et.equals(r, ctx.stash.maxRedeem)
            }},
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, () => ctx.stash.maxRedeem],},
            { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
                et.equals(r.collateralValue / r.liabilityValue, 1.0);
            }, },
            // not a wei more
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, 1], expectError: 'E_AccountLiquidity'},
        { action: 'revert'},

        // more collateral

        { send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(100)], },
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
        { from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [et.eth(1), ctx.wallet2.address]},
        { from: ctx.wallet2, send: 'evc.enableCollateral', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST3.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.28, 0.01);
        }, },

        // debt still fully collateralized by TST2
        { call: 'eVaults.eTST3.maxRedeem', args: [ctx.wallet2.address], equals: et.eth(1)},
        { call: 'eVaults.eTST3.maxWithdraw', args: [ctx.wallet2.address], equals: et.eth(1)},
        // but now can withdraw more TST2
        { action: 'snapshot'},
            { call: 'eVaults.eTST2.maxRedeem', args: [ctx.wallet2.address], onResult: r => {
                ctx.stash.maxRedeem = r
                et.equals(r, '25.75', 0.01)
            }},
            { call: 'eVaults.eTST2.maxWithdraw', args: [ctx.wallet2.address], onResult: r => {
                et.equals(r, ctx.stash.maxRedeem)
            }},
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, () => ctx.stash.maxRedeem],},
            { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
                et.equals(r.collateralValue / r.liabilityValue, 1.0);
            }, },
            // not a wei more
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, 1], expectError: 'E_AccountLiquidity'},
        { action: 'revert'},


        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },
        { action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '2.5', },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.149, 0.001);
        }, },

        { action: 'snapshot'},
            { call: 'eVaults.eTST3.maxRedeem', args: [ctx.wallet2.address], onResult: r => {
                ctx.stash.maxRedeem = r
                et.equals(r, '0.789', '0.01')
            }},
            { from: ctx.wallet2, send: 'eVaults.eTST3.transfer', args: [ctx.wallet5.address, () => ctx.stash.maxRedeem],},
            { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
                et.equals(r.collateralValue / r.liabilityValue, 1.0);
            }, },
            // not a wei more
            { from: ctx.wallet2, send: 'eVaults.eTST3.transfer', args: [ctx.wallet5.address, 1], expectError: 'E_AccountLiquidity'},
        { action: 'revert'},

        { action: 'snapshot'},
            { call: 'eVaults.eTST2.maxRedeem', args: [ctx.wallet2.address], onResult: r => {
                ctx.stash.maxRedeem = r
                et.equals(r, '15.622', 0.01)
            }},
            { call: 'eVaults.eTST2.maxWithdraw', args: [ctx.wallet2.address], onResult: r => {
                et.equals(r, ctx.stash.maxRedeem)
            }},
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, () => ctx.stash.maxRedeem],},
            { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
                et.equals(r.collateralValue / r.liabilityValue, 1.0);
            }, },
            // not a wei more
            { from: ctx.wallet2, send: 'eVaults.eTST2.transfer', args: [ctx.wallet5.address, 1], expectError: 'E_AccountLiquidity'},
        { action: 'revert'},
    ],
})


.test({
    desc: "non-18 decimal collateral",
    actions: ctx => [
        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST9.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },
        { action: 'setLTV', collateral: 'TST9', liability: 'TST', cf: 0.28 },

        { action: 'updateUniswapPrice', pair: 'TST9/WETH', price: '17', },

        { send: 'tokens.TST9.mint', args: [ctx.wallet4.address, et.units(100, 6)], },
        { from: ctx.wallet4, send: 'tokens.TST9.approve', args: [ctx.contracts.eVaults.eTST9.address, et.MaxUint256,], },
        { from: ctx.wallet4, send: 'eVaults.eTST9.deposit', args: [et.units(10, 6), ctx.wallet4.address], },
        { from: ctx.wallet4, send: 'evc.enableCollateral', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST9.address], },

        { from: ctx.wallet4, send: 'evc.enableController', args: [ctx.wallet4.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet4, send: 'eVaults.eTST.borrow', args: [et.eth(20), ctx.wallet4.address], },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet4.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.08, 0.01);
        }, },


        { call: 'eVaults.eTST9.maxRedeem', args: [ctx.wallet4.address], onResult: r => {
            ctx.stash.maxRedeem = r
            et.equals(r, et.units('0.756664', 6))
        }},
        { call: 'eVaults.eTST9.maxWithdraw', args: [ctx.wallet4.address], onResult: r => {
            et.equals(r, ctx.stash.maxRedeem)
        }},
        { from: ctx.wallet4, send: 'eVaults.eTST9.transfer', args: [ctx.wallet5.address, () => ctx.stash.maxRedeem],},
        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet4.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.0, '.0000001');
        }, },
        // not a wei more
        { from: ctx.wallet4, send: 'eVaults.eTST9.transfer', args: [ctx.wallet5.address, 1], expectError: 'E_AccountLiquidity'},
    ],
})

.test({
    desc: "max withdraw with borrow - deposit not enabled as collateral",
    actions: ctx => [
        { from: ctx.wallet2, send: 'evc.enableController', args: [ctx.wallet2.address, ctx.contracts.eVaults.eTST.address], },
        { from: ctx.wallet2, send: 'eVaults.eTST.borrow', args: [et.eth(5), ctx.wallet2.address], },

        // set up liquidator to support the debt
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], },
        { send: 'evc.enableCollateral', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { action: 'setLTV', collateral: 'TST3', liability: 'TST', cf: 0.95 },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 1.09, 0.01);
        }, },

        { send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(100)], },
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.eVaults.eTST3.address, et.MaxUint256,], },
        { from: ctx.wallet2, send: 'eVaults.eTST3.deposit', args: [et.eth(1), ctx.wallet2.address]},

        { call: 'eVaults.eTST3.maxRedeem', args: [ctx.wallet2.address], equals: et.eth(1)},

        { action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2.5', },
        { action: 'updateUniswapPrice', pair: 'TST3/WETH', price: '2.5', },

        { call: 'eVaults.eTST.accountLiquidity', args: [ctx.wallet2.address, false], onResult: r => {
            et.equals(r.collateralValue / r.liabilityValue, 0.96, 0.001);
        }, },

        // TST3 is not enabled as collateral, so withdrawal is NOT prevented in unhealthy state
        { call: 'eVaults.eTST3.maxRedeem', args: [ctx.wallet2.address], equals: 1 },
    ],
})

.run();

const et = require('./eTestLib');


/*
function arrayify(a) {
    if (a === undefined || a === null) return [];
    if (Array.isArray(a)) return a;
    return [a];
}
*/

module.exports = {
/*
    setup: (opts) => ctx => {
        let actions = [];

        if (opts.irm) actions.push({ action: 'setInterestRateModel', irm: opts.irm, });

        if (opts.approveEuler) {
            for (let from of arrayify(opts.approveEuler[0])) {
                for (let tok of arrayify(opts.approveEuler[1])) {
                    actions.push({ from: ctx[from], send: `tokens.${tok}.approve`, args: [ctx.contracts.euler.address, et.MaxUint256,], });
                }
            }
        }
    },
    */

    basicLiquidity: () => ctx => {
        let actions = [
            { action: 'setInterestRateModel', underlying: 'TST', irm: 'irmZero', },
            { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmZero', },
            { action: 'setInterestRateModel', underlying: 'TST3', irm: 'irmZero', },
            { action: 'setInterestRateModel', underlying: 'TST6', irm: 'irmZero', },

            { action: 'setLTV', collateral: 'TST', liability: 'TST2', cf: 0.3 },
            { action: 'setLTV', collateral: 'TST2', liability: 'TST', cf: 0.3 },
            { action: 'setLTV', collateral: 'TST', liability: 'TST3', cf: 0.3 },
            { action: 'setLTV', collateral: 'TST2', liability: 'TST3', cf: 0.3 },
        ];

        for (let from of [ctx.wallet, ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST.approve', args: [ctx.contracts.eVaults.eTST.address, et.MaxUint256,], });
            actions.push({ from, send: 'tokens.TST2.approve', args: [ctx.contracts.eVaults.eTST2.address, et.MaxUint256,], });

            actions.push({ from, send: 'evc.enableCollateral', args: [from.address, ctx.contracts.eVaults.eTST.address], });
            actions.push({ from, send: 'evc.enableCollateral', args: [from.address, ctx.contracts.eVaults.eTST2.address], });
        }

        for (let from of [ctx.wallet]) {
            actions.push({ from, send: 'tokens.TST.mint', args: [from.address, et.eth(100)], });
        }

        for (let from of [ctx.wallet2, ctx.wallet3]) {
            actions.push({ from, send: 'tokens.TST2.mint', args: [from.address, et.eth(100)], });
        }

        actions.push({ from: ctx.wallet, send: 'eVaults.eTST.deposit', args: [et.eth(10), ctx.wallet.address], });

        actions.push({ from: ctx.wallet2, send: 'eVaults.eTST2.deposit', args: [et.eth(10), ctx.wallet2.address], });

        actions.push({ action: 'checkpointTime', });

        actions.push({ action: 'updateUniswapPrice', pair: 'TST/WETH', price: '2', });
        actions.push({ action: 'updateUniswapPrice', pair: 'TST2/WETH', price: '0.083', });

        actions.push({ action: 'jumpTimeAndMine', time: 31*60, });

        return actions;
    },

    swapUni3: () => ctx => [
        { action: 'setMarketConfigRMC', tok: 'WETH', config: { borrowFactor: .4}, },
        { action: 'setMarketConfigRMC', tok: 'TST', config: { borrowFactor: .4}, },
        { action: 'setMarketConfigRMC', tok: 'TST2', config: { borrowFactor: .4}, },
        { action: 'setMarketConfigRMC', tok: 'TST3', config: { borrowFactor: .4}, },
        { action: 'setMarketConfigRMC', tok: 'TST4', config: { borrowFactor: .4 }, },

        { action: 'setLTV', collateral: 'TST', liability: 'WETH', cf: 0.3 },

        // provide liquidity to uni pools
        { send: 'tokens.TST.mint', args: [ctx.wallet2.address, et.eth(1e10)], },
        { from: ctx.wallet2, send: 'tokens.TST.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

        { send: 'tokens.TST2.mint', args: [ctx.wallet2.address, et.eth(1000)], },
        { from: ctx.wallet2, send: 'tokens.TST2.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

        { send: 'tokens.TST3.mint', args: [ctx.wallet2.address, et.eth(1000)], },
        { from: ctx.wallet2, send: 'tokens.TST3.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

        { send: 'tokens.TST4.mint', args: [ctx.wallet2.address, et.eth(1000)], },
        { from: ctx.wallet2, send: 'tokens.TST4.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },

        { send: 'tokens.WETH.mint', args: [ctx.wallet2.address, et.eth(1e10)], },
        { from: ctx.wallet2, send: 'tokens.WETH.approve', args: [ctx.contracts.simpleUniswapPeriphery.address, et.MaxUint256,], },
        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST/WETH'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },
        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST2/WETH'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },
        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST3/WETH'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },
        { cb: () => ctx.contracts.uniswapPools['TST2/TST3'].initialize(et.ratioToSqrtPriceX96(1, 1)) },
        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST2/TST3'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },
        
        // initialize with price 1, adjusted for decimals difference
        { cb: () => ctx.contracts.uniswapPools['TST4/TST'].initialize(ctx.poolAdjustedRatioToSqrtPriceX96('TST4/TST', 1e12, 1)) },
        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST4/TST'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },

        { from: ctx.wallet2, send: 'simpleUniswapPeriphery.mint', args: [ctx.contracts.uniswapPools['TST4/WETH'].address, ctx.wallet2.address, -887220, 887220, et.eth(100)], },
    ],
};

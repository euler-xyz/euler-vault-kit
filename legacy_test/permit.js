const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');

const permitDomain = (symbol, ctx) => ({
    name: `Test Token ${symbol.slice(3)}`,
    version: '1',
    chainId: 1,
    verifyingContract: ctx.contracts.tokens[symbol].address,
});

et.testSet({
    desc: 'permit',
    preActions: ctx => [
        ...scenarios.basicLiquidity()(ctx),
        { send: 'tokens.TST3.mint', args: [ctx.wallet.address, et.eth(100)], },
    ],
})


.test({
    desc: 'EIP2612 standard',
    actions: ctx => [
        {
            action: 'signPermit',
            token: 'TST3',
            signer: ctx.wallet,
            spender: ctx.contracts.eVaults.eTST3.address,
            value: et.eth(11),
            deadline: et.MaxUint256,
            permitType: 'EIP2612',
            domain: permitDomain('TST3', ctx),
            onResult: r => {
                ctx.stash.permit = r;
            },
        },
        { call: 'eVaults.eTST3.maxWithdraw', args: [ctx.wallet.address], assertEql: 0, },
        { call: 'tokens.TST3.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], assertEql: 0, },

        { action: 'sendBatch', batch: [
            { send: 'tokens.TST3.permit(address,address,uint256,uint256,uint8,bytes32,bytes32)', args: [
                ctx.wallet.address,
                ctx.contracts.eVaults.eTST3.address,
                et.eth(11),
                et.MaxUint256,
                () => ctx.stash.permit.signature.v,
                () => ctx.stash.permit.signature.r,
                () => ctx.stash.permit.signature.s
            ], },
            { send: 'eVaults.eTST3.deposit', args: [et.eth(10), ctx.wallet.address], },
        ], },

        // First user loses a small amount to the default reserves
        { call: 'eVaults.eTST3.maxWithdraw', args: [ctx.wallet.address], equals: [et.eth(10), et.formatUnits(et.DefaultReserve)], },
        { call: 'tokens.TST3.allowance', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST3.address], assertEql: et.eth(1), },
    ],
})

.run();

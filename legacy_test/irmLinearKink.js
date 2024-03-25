const et = require('./lib/eTestLib');
const scenarios = require('./lib/scenarios');


function apy(v, tolerance) {
    let apr = Math.log(v + 1);

    let spy = ethers.BigNumber.from(Math.floor(apr * 1e6))
              .mul(ethers.BigNumber.from(10).pow(27 - 6))
              .div(et.SecondsPerYear);

    return spy;
}

function apyInterpolate(apy, frac) {
    return Math.exp(Math.log(1 + apy) * frac) - 1;
}



et.testSet({
    desc: "irm linear kink",

    preActions: scenarios.basicLiquidity(),
})



.test({
    desc: "APRs",
    actions: ctx => [
        { action: 'setInterestRateModel', underlying: 'TST2', irm: 'irmDefault', },
        { send: 'eVaults.eTST.harness_setZeroInterestFee', },

        // 0% utilisation
        { call: 'eVaults.eTST2.interestRate', args: [], equals: [apy(0), 1e-5], },

        // 25% utilisation
        { send: 'evc.enableController', args: [ctx.wallet.address, ctx.contracts.eVaults.eTST2.address], },
        { send: 'eVaults.eTST2.borrow', args: [et.eth(2.5), ctx.wallet.address], },
        { call: 'eVaults.eTST2.interestRate', args: [], equals: [apy(apyInterpolate(.1, .5)), 1e-5], },

        // 50% utilisation
        { send: 'eVaults.eTST2.borrow', args: [et.eth(2.5), ctx.wallet.address], },
        { call: 'eVaults.eTST2.interestRate', args: [], equals: [apy(.1), 1e-5], },

        // 75% utilisation
        { send: 'eVaults.eTST2.borrow', args: [et.eth(2.5), ctx.wallet.address], },
        { call: 'eVaults.eTST2.interestRate', args: [], equals: [apy(3).sub(apy(.1)).div(2).add(apy(.1)), 1e-5], },

        // 100% utilisation
        { send: 'eVaults.eTST2.borrow', args: [et.eth(2.5), ctx.wallet.address], },
        { call: 'eVaults.eTST2.interestRate', args: [], equals: [apy(3), 1e-4], },
    ],
})



.run();

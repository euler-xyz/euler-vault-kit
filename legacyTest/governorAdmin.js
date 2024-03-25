const et = require('./lib/eTestLib');

et.testSet({
    desc: "getting and setting governor admin and IRM",
})

.test({
    desc: "should revert if non governor admin tries to set irmZero for TST token",
    actions: ctx => [
        { from: ctx.wallet2, send: 'eVaults.eTST.setInterestRateModel', args: [ctx.contracts.irms.irmFixed.address], expectError: 'E_Unauthorized', },
    ],
})


.test({
    desc: "should update governor admin, change the IRM for TST token, and retrieve the IRM",
    actions: ctx => [
        { call: 'eVaults.eTST.interestRateModel',  onResult: r => {
            et.expect(r).to.equal(et.AddressZero);
        }},

        { from: ctx.wallet, send: 'eVaults.eTST.setGovernorAdmin', args: [ctx.wallet2.address], },

        { from: ctx.wallet2, send: 'eVaults.eTST.setInterestRateModel', args: [ctx.contracts.irms.irmFixed.address], },

        { call: 'eVaults.eTST.interestRateModel', onResult: r => {
            et.expect(r).to.equal(ctx.contracts.irms.irmFixed.address);
        }},
    ],
})



.run();

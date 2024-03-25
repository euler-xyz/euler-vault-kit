const et = require('./lib/eTestLib');

et.testSet({
    desc: "eVault upgrades and upgrade admin",
})


.test({
    desc: "upgrade eVault",
    actions: ctx => [
        // Fail to upgrade module by non-admin

        { action: 'cb', cb: async () => {
            let factory = await ethers.getContractFactory('JunkEVaultUpgrade');
            let newModule = await (await factory.deploy()).deployed();

            let errMsg;

            try {
                await (await ctx.contracts.genericFactory.connect(ctx.wallet2).setImplementation(newModule.address)).wait();
            } catch (e) {
                errMsg = e.message;
            }

            et.expect(errMsg).to.contain('E_Unauthorized');

            await (await ctx.contracts.genericFactory.connect(ctx.wallet).setImplementation(newModule.address)).wait();

            let newTST = await ethers.getContractAt('JunkEVaultUpgrade', ctx.contracts.eVaults.eTST.address);
            let newName = await newTST.newName();

            et.expect(newName).to.contain('JUNK_UPGRADE_NAME');
        }},

    ],
})

.test({
    desc: "retrieve current upgrade admin",
    actions: ctx => [
        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet.address).to.equal(r);
        }},
    ],
})


.test({
    desc: "successfully update and retrieve new upgrade admin",
    actions: ctx => [
        { from: ctx.wallet, send: 'genericFactory.setUpgradeAdmin', args: [ctx.wallet2.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1);
            et.expect(logs[0].name).to.equal('SetUpgradeAdmin');
            et.expect(logs[0].args.newUpgradeAdmin).to.equal(ctx.wallet2.address);
        }},

        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet2.address).to.equal(r);
        }},
    ],
})


.test({
    desc: "should revert if non upgrade admin tries to set new upgrade admin",
    actions: ctx => [
        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet.address).to.equal(r);
        }},

        { from: ctx.wallet2, send: 'genericFactory.setUpgradeAdmin', args: [ctx.wallet3.address], expectError: 'E_Unauthorized', },

        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet.address).to.equal(r);
        }},
    ],
})


.test({
    desc: "should not allow setting zero address as upgrade admin",
    actions: ctx => [
        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet.address).to.equal(r);
        }},

        { from: ctx.wallet, send: 'genericFactory.setUpgradeAdmin', args: [et.AddressZero], expectError: 'E_BadAddress', },

        { call: 'genericFactory.upgradeAdmin', onResult: r => {
            et.expect(ctx.wallet.address).to.equal(r);
        }},
    ],
})


.run();

// const et = require('./lib/eTestLib');

// const PRICINGTYPE__CHAINLINK = 3;
// let MATIC_ETH_APPROX_PRICE_AT_15399000 = 0;
// let ENS_ETH_APPROX_PRICE_AT_15399000 = 0;

// et.testSet({
//     desc: "underlying/ETH oracle integration",
//     fixture: 'mainnet-fork',
//     forkAtBlock: 15399000,
//     preActions: ctx => [
//         { action: 'cb', cb: async () => {
//             // Get approx prices using current config
//             MATIC_ETH_APPROX_PRICE_AT_15399000 = (await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.MATIC.address)).twap.toString();
//             ENS_ETH_APPROX_PRICE_AT_15399000 = (await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.ENS.address)).twap.toString();
//         }}
//     ]
// })

// .test({
//     desc: "set up and fetch MATIC/ETH and ENS/ETH prices",
//     actions: ctx => [
//         // Get current pricing configuration
//         // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and default 0.3% pool fee

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.MATIC.address], onResult: r => {
//             et.expect(r).to.eql([2, 3000]);
//         }},

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.ENS.address], onResult: r => {
//             et.expect(r).to.eql([2, 3000]);
//         }},

//         // Set up the oracles

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//         [ctx.contracts.tokens.MATIC.address, ctx.contracts.MATICOracle.address], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.MATIC.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.MATICOracle.address.toLowerCase());
//         }},

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//         [ctx.contracts.tokens.ENS.address, ctx.contracts.ENSOracle.address], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.ENS.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.ENSOracle.address.toLowerCase());
//         }},
        
//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//         [ctx.contracts.tokens.MATIC.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.MATIC.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(0);
//         }},

//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//         [ctx.contracts.tokens.ENS.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.ENS.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(0);
//         }},

//         // test getPrice for MATIC
//         { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.MATIC.address], onResult: result => {
//             // Fetch real world price

//             et.expect(result.twap).to.be.within(et.BN(MATIC_ETH_APPROX_PRICE_AT_15399000).mul(99).div(100), et.BN(MATIC_ETH_APPROX_PRICE_AT_15399000).mul(101).div(100));
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // test getPriceFull for MATIC

//         { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.MATIC.address], onResult: result => {
//             // Fetch real world price

//             et.expect(result.twap).to.be.within(et.BN(MATIC_ETH_APPROX_PRICE_AT_15399000).mul(99).div(100), et.BN(MATIC_ETH_APPROX_PRICE_AT_15399000).mul(101).div(100));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // test getPrice for ENS
//         { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.ENS.address], onResult: result => {
//             // Fetch real world price

//             et.expect(result.twap).to.be.within(et.BN(ENS_ETH_APPROX_PRICE_AT_15399000).mul(99).div(100), et.BN(ENS_ETH_APPROX_PRICE_AT_15399000).mul(101).div(100));
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // test getPriceFull for ENS

//         { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.ENS.address], onResult: result => {
//             // Fetch real world price

//             et.expect(result.twap).to.be.within(et.BN(ENS_ETH_APPROX_PRICE_AT_15399000).mul(99).div(100), et.BN(ENS_ETH_APPROX_PRICE_AT_15399000).mul(101).div(100));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },
//     ],
// })

// .run();

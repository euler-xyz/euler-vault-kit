// const et = require('./lib/eTestLib');

// const PRICINGTYPE__CHAINLINK = 3;
// const USDC_ETH_AggregatorProxy = '0x986b5E1e1755e3C2440e960477f25201B0a8bbD4';
// const STETH_ETH_AggregatorProxy = '0x86392dC19c0b719886221c78AB11eb8Cf5c52812';
// const USDC_ETH_APPROX_EXCHANGE_RATE = '323000000000000';
// const STETH_ETH_APPROX_EXCHANGE_RATE = '1000000000000000000';

// et.testSet({
//     desc: "chainlink price feed integration",
//     fixture: 'mainnet-fork',
//     forkAtBlock: 14450000
// })

// .test({
//     desc: "set up and fetch USDC/ETH price",
//     actions: ctx => [
//         // Get current pool pricing configuration
//         // It should return [2, 500], i.e., PRICINGTYPE__UNISWAP3_TWAP and 0.05% pool fee

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.USDC.address], onResult: r => {
//             et.expect(r).to.eql([2, 500]);
//         }},

//         // Get chainlink price feeds configuration (should be default)

//         { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.USDC.address], onResult: r => {
//             et.expect(r).to.eql(et.AddressZero);
//         }},

//         // Cannot set pool pricing configuration if chainlink price feed hadn't been set up previously

//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//             [ctx.contracts.tokens.USDC.address, PRICINGTYPE__CHAINLINK, 0, 0], 
//             expectError: 'POC_ChainlinkPriceFeedNotInitialized', 
//         },

//         // Set up the chainlink price feeds

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//             [ctx.contracts.tokens.USDC.address, USDC_ETH_AggregatorProxy], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.USDC.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(USDC_ETH_AggregatorProxy.toLowerCase());
//         }},

//         // Get chainlink price feed configuration

//         { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.USDC.address], onResult: r => {
//             et.expect(r).to.eql(USDC_ETH_AggregatorProxy);
//         }},

//         // Set pool pricing configuration

//         { from: ctx.wallet, send: 'oracles.priceOracleCore.setPricingConfig', args: 
//             [ctx.contracts.tokens.USDC.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.USDC.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(0);
//         }},

//         // Get current pool pricing configuration

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.USDC.address], onResult: r => {
//             et.expect(r).to.eql([PRICINGTYPE__CHAINLINK, 0]);
//         }},

//         // test getPrice

//         { action: 'cb', cb: async () => {
//             // Fetch real world price

//             const result = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.USDC.address);
//             et.expect(result.twap).to.be.within(et.BN(USDC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(USDC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.twapPeriod).to.equal(0);
//         }},

//         // test getPriceFull

//         { action: 'cb', cb: async () => {
//             // Fetch real world price

//             const result = await ctx.contracts.oracles.priceOracleCore.getPriceFull(ctx.contracts.tokens.USDC.address);
//             et.expect(result.twap).to.be.within(et.BN(USDC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(USDC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }},
//     ],
// })

// .test({
//     desc: "set up and fetch STETH/ETH price",
//     actions: ctx => [
//         // Get current pool pricing configuration
//         // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and 0.3% pool fee

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.STETH.address], onResult: r => {
//             et.expect(r).to.eql([2, 3000]);
//         }},

//         // Get chainlink price feeds configuration (should be default)

//         { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.STETH.address], onResult: r => {
//             et.expect(r).to.eql(et.AddressZero);
//         }},

//         // Cannot set pool pricing configuration if chainlink price feed hadn't been set up previously

//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//             [ctx.contracts.tokens.STETH.address, PRICINGTYPE__CHAINLINK, 0, 0], 
//             expectError: 'POC_ChainlinkPriceFeedNotInitialized', 
//         },

//         // Set up the chainlink price feeds

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//             [ctx.contracts.tokens.STETH.address, STETH_ETH_AggregatorProxy], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.STETH.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(STETH_ETH_AggregatorProxy.toLowerCase());
//         }},

//         // Get chainlink price feed configuration

//         { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.STETH.address], onResult: r => {
//             et.expect(r).to.eql(STETH_ETH_AggregatorProxy);
//         }},

//         // Set pool pricing configuration

//         { from: ctx.wallet, send: 'oracles.priceOracleCore.setPricingConfig', args: 
//             [ctx.contracts.tokens.STETH.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.STETH.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(0);
//         }},

//         // Get current pool pricing configuration

//         { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.STETH.address], onResult: r => {
//             et.expect(r).to.eql([PRICINGTYPE__CHAINLINK, 0]);
//         }},

//         // test getPrice

//         { action: 'cb', cb: async () => {
//             // Fetch real world price

//             const result = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.STETH.address);
//             et.expect(result.twap).to.be.within(et.BN(STETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(STETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.twapPeriod).to.equal(0);
//         }},

//         // test getPriceFull

//         { action: 'cb', cb: async () => {
//             // Fetch real world price

//             const result = await ctx.contracts.oracles.priceOracleCore.getPriceFull(ctx.contracts.tokens.STETH.address);
//             et.expect(result.twap).to.be.within(et.BN(STETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(STETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }},
//     ],
// })

// .run();

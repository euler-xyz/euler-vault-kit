// const et = require('./lib/eTestLib');

// const PRICINGTYPE__CHAINLINK = 3;
// const WBTC_ETH_APPROX_EXCHANGE_RATE = '13800000000000000000';

// et.testSet({
//     desc: "WBTC/ETH oracle integration",
//     fixture: 'mainnet-fork',
//     forkAtBlock: 15998000,
//     preActions: ctx => [
//         { action: 'cb', cb: async () => {
//             // deploy mock chainlink aggregators and corresponding mock oracle

//             ctx.contracts.WBTCBTC_MockChainlinkAggregator = await (await ctx.factories.MockAggregatorProxy.deploy(8)).deployed();
//             ctx.contracts.BTCETH_MockChainlinkAggregator = await (await ctx.factories.MockAggregatorProxy.deploy(18)).deployed();
            
//             ctx.contracts.WBTCOracleMock = await (
//                 await ctx.factories.WBTCOracle.deploy(
//                     ctx.contracts.WBTCBTC_MockChainlinkAggregator.address,
//                     ctx.contracts.BTCETH_MockChainlinkAggregator.address,
//                 )
//             ).deployed();
//         }}
//     ]
// })

// .test({
//     desc: "set up and fetch WBTC/ETH price",
//     actions: ctx => [
//         // Set up the chainlink oracle

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//         [ctx.contracts.tokens.WBTC.address, ctx.contracts.WBTCOracle.address], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WBTC.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.WBTCOracle.address.toLowerCase());
//         }},

//         // Does not revert when setting pricing configuration, even if the new pricing params are 0 (no uniswap fallback)

//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//         [ctx.contracts.tokens.WBTC.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WBTC.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(0);
//         }},

//         // test getPrice
//         { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//             // Fetch real world price
//             // at fork block height 1 WBTC ~= .995 BTC and 1 ETH ~= .721 BTC

//             et.expect(result.twap).to.be.within(et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // test getPriceFull

//         { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//             // Fetch real world price
//             // at fork block height 1 WBTC ~= .995 BTC and 1 ETH ~= .721 BTC

//             et.expect(result.twap).to.be.within(et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // Change configuration to point to mock oracle

//         { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
//             [ctx.contracts.tokens.WBTC.address, ctx.contracts.WBTCOracleMock.address], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WBTC.address.toLowerCase());
//             et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.WBTCOracleMock.address.toLowerCase());
//         }},

//         // set the WBTC/BTC mock chainlink price feed simulating 50% WBTC depeg
//         // set the BTC/ETH mock chainlink price feed to 1 BTC = 4 ETH

//         { send: 'WBTCBTC_MockChainlinkAggregator.mockSetData', args: [[1, 0.5 * 1e8, 0, 0, 0]], },
//         { send: 'BTCETH_MockChainlinkAggregator.mockSetData', args: [[1, et.eth('4'), 0, 0, 0]], },

//         // test getPrice
        
//         { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//             // price = 0.5 * 1e8 * 4e18 / 1e8 = 2e18

//             et.expect(result.twap).to.equal(et.eth('2'));
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // test getPriceFull

//         { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//             // price = 0.5 * 1e8 * 4e18 / 1e8 = 2e18

//             et.expect(result.twap).to.equal(et.eth('2'));
//             et.expect(result.currPrice).to.be.equal(result.twap);
//             et.expect(result.twapPeriod).to.equal(0);
//         }, },

//         // set the mock chainlink price feeds to erroneous values leading to an overflow

//         { send: 'WBTCBTC_MockChainlinkAggregator.mockSetData', args: [[1, et.ethers.constants.MaxUint256.div(2), 0, 0, 0]], },
//         { send: 'BTCETH_MockChainlinkAggregator.mockSetData', args: [[1, et.ethers.constants.MaxUint256.div(2), 0, 0, 0]], },

//         // Due to chainlink price feeds returning erroneous values, the price will revert with overflow
//         // The overflow will be nicely handled by the callChainlinkLatestAnswer() RM function
//         // As uniswap fallback is not configured, it should revert

//         // test getPrice

//         { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WBTC.address], 
//             expectError: 'POC_UnableToGetPrice', 
//         },

//         // test getPriceFull

//         { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WBTC.address], 
//             expectError: 'POC_UnableToGetPrice', 
//         },

//         // configure uniswap fallback pool

//         { send: 'oracles.priceOracleCore.setPricingConfig', args: 
//         [ctx.contracts.tokens.WBTC.address, PRICINGTYPE__CHAINLINK, 3000, 1800], onLogs: logs => {
//             et.expect(logs.length).to.equal(1); 
//             et.expect(logs[0].name).to.equal('GovSetPricingConfig');
//             et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WBTC.address.toLowerCase());
//             et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
//             et.expect(logs[0].args.newPricingParameter).to.equal(3000);
//         }},

//         // even though the WBTC oracle still returns incorrect price of 0, uniswap fallback oracle fetches correct price
//         // test getPrice
//         { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//             // Fetch real world uniswap price
//             // at fork block height 1 WBTC ~= .995 BTC and 1 ETH ~= .721 BTC

//             et.expect(result.twap).to.be.within(et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//             et.expect(result.twapPeriod).to.equal(1800);
//         }, },

//         // test getPriceFull

//         // { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WBTC.address], onResult: result => {
//         //     // Fetch real world uniswap price
//         //     // at fork block height 1 WBTC ~= .995 BTC and 1 ETH ~= .721 BTC

//         //     et.expect(result.twap).to.be.within(et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WBTC_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
//         //     et.expect(result.currPrice).to.be.equal(result.twap);
//         //     et.expect(result.twapPeriod).to.equal(1800);
//         // }, },
//     ],
// })

// .run();

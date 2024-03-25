const et = require('./lib/eTestLib');

const PRICINGTYPE__CHAINLINK = 3;

et.testSet({
    desc: "underlying/ETH oracle",
    preActions: ctx => [
        { action: 'cb', cb: async () => {
            // deploy mock chainlink aggregators and corresponding mock oracle

            ctx.contracts.MockChainlinkAggregator_anyUSD = await (await ctx.factories.MockAggregatorProxy.deploy(8)).deployed();
            ctx.contracts.MockChainlinkAggregator_ETHUSD = await (await ctx.factories.MockAggregatorProxy.deploy(8)).deployed();

            ctx.contracts.MockOracle = await (
                await ctx.factories.ChainlinkBasedOracle.deploy(
                    ctx.contracts.MockChainlinkAggregator_anyUSD.address,
                    ctx.contracts.MockChainlinkAggregator_ETHUSD.address,
                    "any/ETH"
                )
            ).deployed();
        }}
    ]
})

.test({
    desc: "set up and fetch MATIC/ETH and ENS/ETH prices",
    actions: ctx => [
        // Get current pricing configuration
        // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and default 0.3% pool fee

        { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql([2, 3000]);
        }},

        // Set up the oracles

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
        [ctx.contracts.tokens.TST.address, ctx.contracts.MockOracle.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.TST.address.toLowerCase());
            et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.MockOracle.address.toLowerCase());
        }},
        
        { send: 'oracles.priceOracleCore.setPricingConfig', args: 
        [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.TST.address.toLowerCase());
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(0);
        }},

        // Update mocked prices

        { send: 'MockChainlinkAggregator_anyUSD.mockSetData', args: [[1, 2, 0, 0, 0]], },
        { send: 'MockChainlinkAggregator_ETHUSD.mockSetData', args: [[1, 1, 0, 0, 0]], },

        // the price should be
        // price = 2 * 1e18 / 1 = 2e18

        // test getPrice
        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.equal(et.eth(2));
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.equal(et.eth(2));
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // Update mocked prices

        { send: 'MockChainlinkAggregator_anyUSD.mockSetData', args: [[1, 10, 0, 0, 0]], },
        { send: 'MockChainlinkAggregator_ETHUSD.mockSetData', args: [[1, 2, 0, 0, 0]], },

        // the price should be
        // price = 10 * 1e18 / 2 = 5e18

        // test getPrice
        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.equal(et.eth(5));
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.equal(et.eth(5));
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // Invalidate mocked prices, should lead to revert as uniswap fallback not set

        { send: 'MockChainlinkAggregator_anyUSD.mockSetData', args: [[1, 0, 0, 0, 0]], },
        { send: 'MockChainlinkAggregator_ETHUSD.mockSetData', args: [[1, 1, 0, 0, 0]], },

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // Invalidate mocked prices, should lead to revert as uniswap fallback not set

        { send: 'MockChainlinkAggregator_anyUSD.mockSetData', args: [[1, 1, 0, 0, 0]], },
        { send: 'MockChainlinkAggregator_ETHUSD.mockSetData', args: [[1, 0, 0, 0, 0]], },

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },
    ],
})

.test({
    desc: "test misc functions of MATIC and ENS oracles",
    actions: ctx => [
        // test decimals function

        { call: 'MockOracle.decimals', onResult: r => {
            et.expect(r).to.equal(18);
        }, },

        // test description function

        { call: 'MockOracle.description', onResult: r => {
            et.expect(r).to.equal("any/ETH");
        }, },

        // test latestTimestamp function

        { send: 'MockChainlinkAggregator_anyUSD.mockSetData', args: [[1, 0, 123456, 0, 0]], },
        { send: 'MockChainlinkAggregator_ETHUSD.mockSetData', args: [[0, 0, 0, 0, 0]], },

        { call: 'MockOracle.latestTimestamp', onResult: r => {
            et.expect(r).to.equal(123456);
        }, },
    ]
})

.run();

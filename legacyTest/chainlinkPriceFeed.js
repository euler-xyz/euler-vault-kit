const et = require('./lib/eTestLib');

const PRICINGTYPE__CHAINLINK = 3;
const PRICINGTYPE__OUT_OF_BOUNDS = 5;

et.testSet({
    desc: "chainlink price feed handling",
    preActions: ctx => [
        { action: 'cb', cb: async () => {
            // deploy mock chainlink aggregator

            ctx.contracts.AggregatorTST = await (await ctx.factories.MockAggregatorProxy.deploy(18)).deployed();
        }}
    ]
})

.test({
    desc: "chainlink pricing setup and price fetch",
    actions: ctx => [
        // Get current pool pricing configuration
        // // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and default pool fee

        { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql([2, et.DefaultUniswapFee]);
        }},

        // Get chainlink price feed configuration (should be default)

        { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql(et.AddressZero);
        }},

        // Cannot set pool pricing configuration if price feeds hadn't been set up previously

        { send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, et.DefaultUniswapFee, 0], 
            expectError: 'POC_ChainlinkPriceFeedNotInitialized', 
        },

        // Cannot set price feed address if zero address provided

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: [ctx.contracts.tokens.TST.address, et.AddressZero],
            expectError: 'POC_BadChainlinkAddress', 
        },

        // Set up the price feeds

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
            [ctx.contracts.tokens.TST.address, ctx.contracts.AggregatorTST.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset).to.equal(ctx.contracts.tokens.TST.address);
            et.expect(logs[0].args.chainlinkAggregator).to.equal(ctx.contracts.AggregatorTST.address);
        }},

        // Get chainlink price feed configuration

        { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql(ctx.contracts.AggregatorTST.address);
        }},

        // Cannot set pool pricing configuration if the new pricing type out of bound

        { send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, PRICINGTYPE__OUT_OF_BOUNDS, et.DefaultUniswapFee, 0], 
            expectError: 'POC_BadPricingType', 
        },

        // Set pool pricing configuration

        { send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, et.DefaultUniswapFee, 1800], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset).to.equal(ctx.contracts.tokens.TST.address);
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(et.DefaultUniswapFee);
        }},

        // Get current pool pricing configuration

        { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql([PRICINGTYPE__CHAINLINK, et.DefaultUniswapFee]);
        }},

        // test getPrice

        { action: 'cb', cb: async () => {
            // Set up the price feeds and fetch prices

            await ctx.contracts.AggregatorTST.mockSetData([1, 123456, 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(123456);
            et.expect(resultTST.twapPeriod).to.equal(0);
        }},

        // test getPriceFull

        { action: 'cb', cb: async () => {
            // Set up the price feeds and fetch prices

            await ctx.contracts.AggregatorTST.mockSetData([1, 123456, 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPriceFull(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(123456);
            et.expect(resultTST.currPrice).to.equal(resultTST.twap);
            et.expect(resultTST.twapPeriod).to.equal(0);
        }},

        { action: 'cb', cb: async () => {
            // Set uniswap prices
            await ctx.updateUniswapPrice('TST/WETH', 1000);

            // Set invalid prices and fetch them (we should fall back to uniswap twap and its 30 min period )

            await ctx.contracts.AggregatorTST.mockSetData([3, 0, 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(1000);
            et.expect(resultTST.twapPeriod).to.equal(30 * 60);
        }},

        // Set pool pricing configuration with no uniswap fallback poool

        { send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset).to.equal(ctx.contracts.tokens.TST.address);
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(0);
        }},

        { action: 'cb', cb: async () => {
            // Set uniswap prices
            await ctx.updateUniswapPrice('TST/WETH', 5);

            // Set invalid prices and fetch them (we should revert as there's no uniswap fallback pool)

            await ctx.contracts.AggregatorTST.mockSetData([3, 0, 0, 0, 0]);
            let errMsg = '';
            try {
                await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.TST.address);
            } catch (e) {
                errMsg = e.message;
            }
            et.expect(errMsg).to.contains('POC_UnableToGetPrice');
        }},
    ],
})


.test({
    desc: "chainlink pricing serving max price",
    actions: ctx => [

        // Set up the price feeds

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
            [ctx.contracts.tokens.TST.address, ctx.contracts.AggregatorTST.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset).to.equal(ctx.contracts.tokens.TST.address);
            et.expect(logs[0].args.chainlinkAggregator).to.equal(ctx.contracts.AggregatorTST.address);
        }},

        // Set pool pricing configuration

        { send: 'oracles.priceOracleCore.setPricingConfig', args: [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, et.DefaultUniswapFee, 0], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset).to.equal(ctx.contracts.tokens.TST.address);
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(et.DefaultUniswapFee);
        }},

        // test getPrice

        { action: 'cb', cb: async () => {
            // Set up the price equal to the max price of 1e36

            await ctx.contracts.AggregatorTST.mockSetData([1, et.ethers.utils.parseUnits('1', 36), 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(et.ethers.utils.parseUnits('1', 36));
            et.expect(resultTST.twapPeriod).to.equal(0);
        }},

        // test getPriceFull

        { action: 'cb', cb: async () => {
            // Set up the price equal to the max price of 1e36

            await ctx.contracts.AggregatorTST.mockSetData([1, et.ethers.utils.parseUnits('1', 36), 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPriceFull(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(et.ethers.utils.parseUnits('1', 36));
            et.expect(resultTST.currPrice).to.equal(resultTST.twap);
            et.expect(resultTST.twapPeriod).to.equal(0);
        }},

        // test getPrice

        { action: 'cb', cb: async () => {
            // Set up the price that exceeds the max price of 1e36

            await ctx.contracts.AggregatorTST.mockSetData([1, et.ethers.utils.parseUnits('1', 36).add(1), 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPrice(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(et.ethers.utils.parseUnits('1', 36));
            et.expect(resultTST.twapPeriod).to.equal(0);
        }},

        // test getPriceFull

        { action: 'cb', cb: async () => {
            // Set up the price that exceeds the max price of 1e36

            await ctx.contracts.AggregatorTST.mockSetData([1, et.ethers.utils.parseUnits('1', 36).add(1), 0, 0, 0]);
            const resultTST = await ctx.contracts.oracles.priceOracleCore.getPriceFull(ctx.contracts.tokens.TST.address);
            et.expect(resultTST.twap).to.equal(et.ethers.utils.parseUnits('1', 36));
            et.expect(resultTST.currPrice).to.equal(resultTST.twap);
            et.expect(resultTST.twapPeriod).to.equal(0);
        }}
    ],
})

.run();

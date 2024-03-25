const et = require('./lib/eTestLib');

const PRICINGTYPE__CHAINLINK = 3;

et.testSet({
    desc: "wstETH/ETH oracle",
    preActions: ctx => [
        { action: 'cb', cb: async () => {
            // deploy mock chainlink aggregator, mock stETH and corresponding mock oracle

            ctx.contracts.MockChainlinkAggregator = await (await ctx.factories.MockAggregatorProxy.deploy(18)).deployed();
            ctx.contracts.MockStETH = await (await ctx.factories.MockStETH.deploy()).deployed();

            ctx.contracts.WSTETHOracle = await (
                await ctx.factories.WSTETHOracle.deploy(
                    ctx.contracts.MockStETH.address,
                    ctx.contracts.MockChainlinkAggregator.address,
                )
            ).deployed();
        }}
    ]
})

.test({
    desc: "set up and fetch WSTETH/ETH price",
    actions: ctx => [
        // Get current pools pricing configuration
        // It should return [2, 3000], i.e., PRICINGTYPE__UNISWAP3_TWAP and default 0.3% pool fee

        { call: 'oracles.priceOracleCore.getPricingConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.eql([2, 3000]);
        }},

        // Get chainlink oracle configuration (should be unconfigured)

        { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.equal(et.AddressZero);
        }},

        // Cannot set pricing configuration if chainlink oracle hadn't been set up before

        { send: 'oracles.priceOracleCore.setPricingConfig', args: 
            [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, 0, 0], 
            expectError: 'POC_ChainlinkPriceFeedNotInitialized', 
        },

        // Set up the chainlink oracle to the mock

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
            [ctx.contracts.tokens.TST.address, ctx.contracts.WSTETHOracle.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.TST.address.toLowerCase());
            et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.WSTETHOracle.address.toLowerCase());
        }},

        // Get chainlink oracle configuration

        { call: 'oracles.priceOracleCore.getChainlinkPriceFeedConfig', args: [ctx.contracts.tokens.TST.address], onResult: r => {
            et.expect(r).to.equal(ctx.contracts.WSTETHOracle.address);
        }},   

        // Does not revert when setting pricing configuration, even if the new pricing params are 0 (no uniswap fallback)

        { send: 'oracles.priceOracleCore.setPricingConfig', args: 
            [ctx.contracts.tokens.TST.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.TST.address.toLowerCase());
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(0);
        }},

        // Change mocked price to 1000, set the exchange rate to 1.03

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 1000, 0, 0, 0]], },
        { send: 'MockStETH.mockSetData', args: [et.ethers.utils.parseEther('1.03'), 1], },

        // test getPrice

        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.be.equal(1030);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.be.equal(1030);
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // invalidate the mock chainlink price feed by returning price of 0

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 0, 0, 0, 0]], },

        // Due to incorrect chainlink price, the price returned by wstETH oracle will be 0
        // As uniswap fallback is not configured, it should revert

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // set the mock chainlink price feed correctly to price of 500, the exchange rate is still 1.03

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 500, 0, 0, 0]], },
        { send: 'MockStETH.mockSetData', args: [et.ethers.utils.parseEther('1.03'), 1], },

        // test getPrice

        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.be.equal(515);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], onResult: result => {
            et.expect(result.twap).to.be.equal(515);
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // set the mock chainlink price feed correctly to price of 1000
        // make the stETH contract revert when trying to fetch the exchange rate

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 1000, 0, 0, 0]], },
        { send: 'MockStETH.mockSetRevert', args: [true], },
        { send: 'MockStETH.mockSetData', args: [1, 1], },

        // Due to stETH contract revering, the price returned by wstETH oracle will be 0
        // As uniswap fallback is not configured, it should revert

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // set the mock chainlink price feed correctly to price of 1000
        // make the stETH contract return 0 for the exchange rate

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 1000, 0, 0, 0]], },
        { send: 'MockStETH.mockSetRevert', args: [false], },
        { send: 'MockStETH.mockSetData', args: [0, 1], },

        // Due to stETH contract returning 0 as exchange rate, the price returned by wstETH oracle will be 0
        // As uniswap fallback is not configured, it should revert

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.TST.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // set the mock chainlink price feed correctly to price of 1e18
        // make the stETH contract return erroneous (too big) value for the exchange rate leading to an overflow
        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, et.ethers.utils.parseEther('1'), 0, 0, 0]], },
        { send: 'MockStETH.mockSetData', args: [et.ethers.constants.MaxUint256, 1], },

        // Due to stETH contract returning erroneous value as exchange rate, the price will revert with overflow
        // The overflow will be nicely handled by the callChainlinkLatestAnswer() RM function
        // As uniswap fallback is not configured, it should revert

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
    desc: "test misc functions of WSTETH/ETH oracle",
    actions: ctx => [
        // test decimals function

        { call: 'WSTETHOracle.decimals', onResult: r => {
            et.expect(r).to.equal(18);
        }, },

        // test description function

        { call: 'WSTETHOracle.description', onResult: r => {
            et.expect(r).to.equal("WSTETH/ETH");
        }, },

        // test latestTimestamp function

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, 0, 123, 0, 0]], },

        { call: 'WSTETHOracle.latestTimestamp', onResult: r => {
            et.expect(r).to.equal(123);
        }, },
    ]
})

.run();

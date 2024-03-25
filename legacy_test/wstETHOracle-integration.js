const et = require('./lib/eTestLib');

const PRICINGTYPE__CHAINLINK = 3;
const WSTETH_ETH_APPROX_EXCHANGE_RATE = '1070000000000000000';

et.testSet({
    desc: "wstETH/ETH oracle integration",
    fixture: 'mainnet-fork',
    forkAtBlock: 14707000,
    preActions: ctx => [
        { action: 'cb', cb: async () => {
            // deploy mock chainlink aggregator, mock stETH and corresponding mock oracle

            ctx.contracts.MockChainlinkAggregator = await (await ctx.factories.MockAggregatorProxy.deploy(18)).deployed();
            ctx.contracts.MockStETH = await (await ctx.factories.MockStETH.deploy()).deployed();

            ctx.contracts.WSTETHOracleMock = await (
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
        // Set up the chainlink oracle

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
        [ctx.contracts.tokens.WSTETH.address, ctx.contracts.WSTETHOracle.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WSTETH.address.toLowerCase());
            et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.WSTETHOracle.address.toLowerCase());
        }},

        // Does not revert when setting pricing configuration, even if the new pricing params are 0 (no uniswap fallback)

        { send: 'oracles.priceOracleCore.setPricingConfig', args: 
        [ctx.contracts.tokens.WSTETH.address, PRICINGTYPE__CHAINLINK, 0, 0], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WSTETH.address.toLowerCase());
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(0);
        }},

        // test getPrice
        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // Fetch real world price
            // at fork block height 1 stETH ~= 1 ETH

            et.expect(result.twap).to.be.within(et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // Fetch real world price
            // at fork block height 1 stETH ~= 1 ETH

            et.expect(result.twap).to.be.within(et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // Change configuration to point to mock oracle

        { send: 'oracles.priceOracleCore.setChainlinkPriceFeed', args: 
            [ctx.contracts.tokens.WSTETH.address, ctx.contracts.WSTETHOracleMock.address], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetChainlinkPriceFeed');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WSTETH.address.toLowerCase());
            et.expect(logs[0].args.chainlinkAggregator.toLowerCase()).to.equal(ctx.contracts.WSTETHOracleMock.address.toLowerCase());
        }},

        // set the mock chainlink price feed correctly to price of 1e18 / 2
        // set the exchange rate to 2 in the stETH mock

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, et.ethers.utils.parseEther('1').div(2), 0, 0, 0]], },
        { send: 'MockStETH.mockSetData', args: [2, 1], },

        // test getPrice

        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // price = 1e18 / 2 * 2 / 1e18 = 1

            et.expect(result.twap).to.equal(1);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // price = 1e18 / 2 * 2 / 1e18 = 1

            et.expect(result.twap).to.equal(1);
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(0);
        }, },

        // set the mock chainlink price feed correctly to price of 1e18
        // make the stETH contract return erroneous (too big) value for the exchange rate leading to an overflow

        { send: 'MockChainlinkAggregator.mockSetData', args: [[1, et.ethers.utils.parseEther('1'), 0, 0, 0]], },
        { send: 'MockStETH.mockSetData', args: [et.ethers.constants.MaxUint256, 1], },

        // Due to stETH contract returning erroneous value as exchange rate, the price will revert with overflow
        // The overflow will be nicely handled by the callChainlinkLatestAnswer() RM function
        // As uniswap fallback is not configured, it should revert

        // test getPrice

        { send: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WSTETH.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // test getPriceFull

        { send: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WSTETH.address], 
            expectError: 'POC_UnableToGetPrice', 
        },

        // configure uniswap fallback pool

        { send: 'oracles.priceOracleCore.setPricingConfig', args: 
        [ctx.contracts.tokens.WSTETH.address, PRICINGTYPE__CHAINLINK, 500, 1800], onLogs: logs => {
            et.expect(logs.length).to.equal(1); 
            et.expect(logs[0].name).to.equal('GovSetPricingConfig');
            et.expect(logs[0].args.asset.toLowerCase()).to.equal(ctx.contracts.tokens.WSTETH.address.toLowerCase());
            et.expect(logs[0].args.newPricingType).to.equal(PRICINGTYPE__CHAINLINK);
            et.expect(logs[0].args.newPricingParameter).to.equal(500);
        }},

        // even though the wstETH oracle still returns incorrect price of 0, uniswap fallback oracle fetches correct price
        // test getPrice

        { call: 'oracles.priceOracleCore.getPrice', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // Fetch real world uniswap price
            // at fork block height 1 stETH ~= 1 ETH

            et.expect(result.twap).to.be.within(et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
            et.expect(result.twapPeriod).to.equal(1800);
        }, },

        // test getPriceFull

        { call: 'oracles.priceOracleCore.getPriceFull', args: [ctx.contracts.tokens.WSTETH.address], onResult: result => {
            // Fetch real world uniswap price
            // at fork block height 1 stETH ~= 1 ETH

            et.expect(result.twap).to.be.within(et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(995).div(1000), et.BN(WSTETH_ETH_APPROX_EXCHANGE_RATE).mul(1005).div(1000));
            et.expect(result.currPrice).to.be.equal(result.twap);
            et.expect(result.twapPeriod).to.equal(1800);
        }, },
    ],
})

.run();

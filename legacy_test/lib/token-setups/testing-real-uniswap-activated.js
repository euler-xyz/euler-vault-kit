module.exports = {
    testing: {
        tokens: [
            {
                name: "Wrapped ETH",
                symbol: "WETH",
                decimals: 18,
                config: {
                    collateralFactor: 0.75,
                },
            },
            {
                name: "Test Token",
                symbol: "TST",
                decimals: 18,
                config: {
                    collateralFactor: 0.75,
                },
            },
            {
                name: "Test Token 2",
                symbol: "TST2",
                decimals: 18,
                config: {
                    collateralFactor: 0.75,
                },
            },
            {
                name: "Test Token 3",
                symbol: "TST3",
                decimals: 18,
                config: {
                    collateralFactor: 0.75,
                },
            },
            {
                name: "Test Token 4",
                symbol: "TST4",
                decimals: 6,
            },
            {
                name: "Uninited Test Token 3",
                symbol: "UTST",
                decimals: 18,
            }
        ],

        useRealUniswap: true,

        uniswapPools: [
            ["TST", "WETH"],
            ["TST2", "WETH"],
            ["TST3", "WETH"],
            ["TST4", "WETH"],
            ["TST2", "TST3"],
            ["TST4", "TST"],
        ],

        activated: [
            "WETH",
            "TST",
            "TST2",
            "TST3",
            "TST4",
        ],
    },
};

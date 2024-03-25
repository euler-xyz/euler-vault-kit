module.exports = {
    testing: {
        tokens: [
            {
                name: "Wrapped ETH",
                symbol: "WETH",
                decimals: 18,
            },
            {
                name: "Test Token",
                symbol: "TST",
                decimals: 18,
            },
            {
                name: "Test Token 2",
                symbol: "TST2",
                decimals: 6,
            },
            {
                name: "Test Token 3",
                symbol: "TST3",
                decimals: 0,
            },
            {
                name: "Test Token 4",
                symbol: "TST4",
                decimals: 18,
            },
            {
                name: "Test Token 5",
                symbol: "TST5",
                decimals: 0,
            },
            {
                name: "Test Token 6",
                symbol: "TST6",
                decimals: 6,
            },
        ],

        useRealUniswap: true,

        uniswapPools: [
            ["TST", "WETH"],
            ["TST2", "WETH"],
            ["TST3", "WETH"],
            ["TST5", "WETH"],
            ["TST6", "WETH"],
        ],

        activated: [
        ],
    },
};

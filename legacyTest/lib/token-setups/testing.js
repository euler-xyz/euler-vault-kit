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
            },
            {
                name: "Test Token 4",
                symbol: "TST4",
                decimals: 18,
            },
            {
                name: "Test Token 5",
                symbol: "TST5",
                decimals: 18,
            },
            {
                name: "Test Token 6",
                symbol: "TST6",
                decimals: 18,
            },
            {
                name: "Test Token 7",
                symbol: "TST7",
                decimals: 18,
            },
            {
                name: "Test Token 8",
                symbol: "TST8",
                decimals: 6,
            },
            {
                name: "Test Token 9",
                symbol: "TST9",
                decimals: 6,
            },
            {
                name: "Test Token 10",
                symbol: "TST10",
                decimals: 0,
            },
            {
                name: "Unactivated Test Token",
                symbol: "UTST",
                decimals: 18,
            },
            {
                name: "Test Token 11",
                symbol: "TST11",
                decimals: 18,
            },
            {
                name: "Test Token 12",
                symbol: "TST12",
                decimals: 8,
            },
            {
                name: "Test Token 13",
                symbol: "TST13",
                decimals: 18,
            },
            {
                name: "Test Token 14",
                symbol: "TST14",
                decimals: 18,
            },
            {
                name: "Euler Token",
                symbol: "EUL",
                decimals: 18,
            },
        ],

        uniswapPools: [
            ["TST", "WETH"],
            ["TST2", "WETH"],
            ["TST3", "WETH"],
            ["TST6", "WETH"],
            ["TST7", "WETH"],
            ["TST8", "WETH"],
            ["TST9", "WETH"],
            ["TST10", "WETH"],
            ["TST11", "WETH"],
            ["TST12", "WETH"],
            ["TST13", "WETH"],
            ["TST14", "WETH"],
            ["UTST", "WETH"],
        ],

        activated: [
            "WETH",
            "TST",
            "TST2",
            "TST3",
            "TST6", // TST6 address is the first one < the WETH address which exercises uniswap's address sorting
            "TST9", // Has 6 decimals
            "TST10", // Has 0 decimals
            "TST11", // Has 18 decimals
            "TST12", // Has 8 decimals
            "TST13", // Has 18 decimals
            "TST14", // Has 18 decimals
        ],

        externalVaults: [
            {
                asset: "TST7",
                decimals: 18, // same as asset
            },
            {
                asset: "TST8",
                decimals: 6, // same as asset
            },
            {
                asset: "TST12",
                decimals: 18, // asset has 8
            },
            {
                asset: "TST13",
                decimals: 6, // asset has 18
            },
        ]
    },
};

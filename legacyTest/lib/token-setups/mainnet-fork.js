module.exports = {
    oracleSettings: {
        referenceAsset: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
        uniswapFactory: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
        uniswapPoolInitCodeHash: '0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54',
    },

    existingContracts: {
        swapRouterV2: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
        swapRouterV3: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
        swapRouter02: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
        oneInch: '0x1111111254fb6c44bAC0beD2854e76F90643097d',
        chainlinkAggregator_STETH_ETH: '0x86392dc19c0b719886221c78ab11eb8cf5c52812',
        chainlinkAggregator_ETH_USD: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
        chainlinkAggregator_MATIC_USD: '0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676',
        chainlinkAggregator_ENS_USD: '0x5C00128d4d1c2F4f652C267d7bcdD7aC99C16E16',
        chainlinkAggregator_WBTC_BTC: '0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23',
        chainlinkAggregator_BTC_ETH: '0xdeb288F737066589598e9214E782fa5A8eD689e8',
    },

    testing: {
        forkTokens: {
            BAT: {
                address: '0x0d8775f648430679a709e98d2b0cb6250d2887ef',
            },
            RGT: {
                address: '0xd291e7a03283640fdc51b121ac401383a46cc623',
            },
            USDT: {
                address: '0xdac17f958d2ee523a2206206994597c13d831ec7',
            },
            USDC: {
                address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                permit: {
                    type: "EIP2612",
                    domain: {
                        name: "USD Coin",
                        version: "2",
                        chainId: 1,
                        verifyingContract: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    },
                },
            },
            DAI: {
                address: '0x6b175474e89094c44da98b954eedeac495271d0f',
                permit: {
                    type: "Allowed",
                    domain: {
                        name: "Dai Stablecoin",
                        version: "1",
                        chainId: 1,
                        verifyingContract: "0x6b175474e89094c44da98b954eedeac495271d0f",
                    },
                },
            },
            GRT: {
                address: '0xc944e90c64b2c07662a292be6244bdf05cda44a7',
                permit: {
                    type: 'EIP2612',
                    domain: {
                        name: "Graph Token",
                        version: "0",
                        chainId: 1,
                        verifyingContract: '0xc944e90c64b2c07662a292be6244bdf05cda44a7',
                        salt: '0x51f3d585afe6dfeb2af01bba0889a36c1db03beec88c6a4d0c53817069026afa',
                    },
                },
            },
            YVBOOST: {
                address: '0x9d409a0a012cfba9b15f6d4b36ac57a46966ab9a',
                permit: {
                    type: "Packed",
                    domain: {
                        name: "Yearn Vault",
                        version: "0.3.5",
                        chainId: 1,
                        verifyingContract: "0x9d409a0a012cfba9b15f6d4b36ac57a46966ab9a",
                    },
                },
            },
            STETH: {
                address: '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84',
            },
            WSTETH: {
                address: '0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0',
            },
            MATIC: {
                address: '0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0',
            },
            ENS: {
                address: '0xc18360217d8f7ab5e7c516566761ea12ce7f9d72',
            },
            WBTC: {
                address: '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599',
            },
        },

        uniswapPools: [],

        activated: [
            "BAT",
            "RGT",
            "USDT",
            "USDC",
            "DAI",
            "GRT",
            "YVBOOST",
            "STETH",
            "WSTETH",
            "MATIC",
            "ENS",
            "WBTC",
        ],
    },
};


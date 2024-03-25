// require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

const fs = require("fs");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-contract-sizer");
require('hardhat-gas-reporter');
require("solidity-coverage");
require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    networks: {
        hardhat: {
            hardfork: 'shanghai',
            chainId: 1,
            allowUnlimitedContractSize: true,
        },
        localhost: {
            chainId: 1,
            url: "http://127.0.0.1:8545",
            timeout: 5 * 60 * 1000, 
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.23",
                settings: {
                    optimizer: {
                    enabled: true,
                        runs: 1000000,
                    },
                },
            },
        ],
    },
    paths: {
        sources: "./src/",
        tests: "./legacy_test/",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    gasReporter: {
        enabled: !!process.env.REPORT_GAS,
    },

    contractSizer: {
        runOnCompile: !!process.env.SIZER,
    },

    mocha: {
        timeout: 100000
    }
};

let doSkipFork;
task("test")
    .addFlag("skipfork", "Skip tests on mainnet fork")
    .setAction(({ skipfork }) => {
        if (!process.env.ALCHEMY_API_KEY) {
            console.log('\nALCHEMY_API_KEY environment variable not found. Skipping integration tests on mainnet fork...\n');
            doSkipFork = true;
        } else {
            doSkipFork = skipfork;
        }

        return runSuper();
    });

subtask("test:get-test-files")
    .setAction(async () => {
        let files = await runSuper();

        if (doSkipFork || process.env.COVERAGE) {
            files = files.filter(f => !f.includes('-integration'));
        }
        return files;
    });
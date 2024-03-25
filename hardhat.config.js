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
  solidity: "0.8.24",
  paths: {
    sources: "./src",
    tests: "./legacyTest",
    cache: "./cache",
    artifacts: "./artifacts"
  },
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
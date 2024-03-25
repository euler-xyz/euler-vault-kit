const et = require('./lib/eTestLib');


async function main() {
    // To verify storage layouts are consistent across upgrades
    //let buildInfo = await hre.artifacts.getBuildInfo('contracts/Storage.sol:Storage');
    //let storageInfo = buildInfo.output.contracts['contracts/Storage.sol'].Storage.storageLayout;
    //console.log(et.dumpObj(storageInfo));

    // To inspect asm:
    //let buildInfo = await hre.artifacts.getBuildInfo('contracts/modules/DToken.sol:DToken');
    //let asm = buildInfo.output.contracts['contracts/modules/DToken.sol'].DToken.evm.assembly;
    //console.log(asm);
}

main();

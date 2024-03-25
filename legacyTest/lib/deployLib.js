async function verifyBatch(verification) {
    
    if (Object.keys(verification.contracts.tokens).length > 0) {
        console.log("Verifying test tokens");
        for (let token of Object.keys(verification.contracts.tokens)) {
            console.log(token, verification.contracts.tokens[token].address, verification.contracts.tokens[token].args, verification.contracts.tokens[token].contractPath);
            await verifyContract(verification.contracts.tokens[token].address, verification.contracts.tokens[token].args, verification.contracts.tokens[token].contractPath);
        }
    }
    
    if (Object.keys(verification.contracts.modules).length > 0) {
        console.log("Verifying modules");
        for (let module of Object.keys(verification.contracts.modules)) {
            console.log(module, verification.contracts.modules[module].address, verification.contracts.modules[module].args, verification.contracts.modules[module].contractPath);
            await verifyContract(verification.contracts.modules[module].address, verification.contracts.modules[module].args, verification.contracts.modules[module].contractPath);
        }
    }
    
    if (Object.keys(verification.contracts.swapHandlers).length > 0) {
        console.log("Verifying swap handlers");
        for (let handler of Object.keys(verification.contracts.swapHandlers)) {
            console.log(handler, verification.contracts.swapHandlers[handler].address, verification.contracts.swapHandlers[handler].args, verification.contracts.swapHandlers[handler].contractPath);
            await verifyContract(verification.contracts.swapHandlers[handler].address, verification.contracts.swapHandlers[handler].args, verification.contracts.swapHandlers[handler].contractPath);
        }
    }
    
    if (Object.keys(verification.contracts).length > 0) {
        console.log("Verifying euler contracts");
        for (let contract of Object.keys(verification.contracts)) {
            if (verification.contracts[contract].address && verification.contracts[contract].args) {
                console.log(contract, verification.contracts[contract].address, verification.contracts[contract].args, verification.contracts[contract].contractPath);
                await verifyContract(verification.contracts[contract].address, verification.contracts[contract].args, verification.contracts[contract].contractPath);
            }
        }
    }
    
}

async function verifyContract(contractAddress, contractArgs, contractPath = null) {
    try {
        if (contractPath) {
            await run("verify:verify", {
                address: contractAddress,
                constructorArguments: [...contractArgs],
                contract: contractPath
            });
        } else {
            await run("verify:verify", {
                address: contractAddress,
                constructorArguments: [...contractArgs],
            });
        }

    } catch (error) {
        console.log(`Smart contract verification for contract at ${contractAddress}, was not successful\n ${error.message}`);
    }
}

module.exports = {
    verifyBatch,
    verifyContract
}

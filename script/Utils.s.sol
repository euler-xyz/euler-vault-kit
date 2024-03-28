// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Script.sol";

contract Utils is Script {
    function startBroadcast() internal {
        uint256 anvilPrivateKey = vm.deriveKey(vm.envString("ANVIL_MNEMONIC"), 0);
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_KEY", uint256(1));
        address deployer = vm.addr(deployerPrivateKey);

        vm.broadcast(anvilPrivateKey);
        (bool success,) = deployer.call{value: 10 ether}("");
        vm.deal(deployer, 10 ether);
        require(success || deployer.balance != 0, "Deployment: insufficient funds");

        deployerPrivateKey == 1 ? vm.startBroadcast() : vm.startBroadcast(deployerPrivateKey);
    }

    function getDeployer() internal view returns (address) {
        return vm.addr(vm.envOr("DEPLOYER_KEY", uint256(1)));
    }

    function getConfig(string memory dir, string memory jsonFile) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/input/", dir, "/", jsonFile);
        return vm.readFile(configPath);
    }
}

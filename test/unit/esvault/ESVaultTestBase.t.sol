// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../evault/EVaultTestBase.t.sol";
import {ESVault} from "../../../src/Synths/ESVault.sol";
import {IEVault, IERC20} from "../../../src/EVault/IEVault.sol";
import {IRMTestDefault} from "../../mocks/IRMTestDefault.sol";
import {ESynth} from "../../../src/Synths/ESynth.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";

contract ESVaultTestBase is EVaultTestBase {
    ESynth assetTSTAsSynth;
    ESynth assetTST2AsSynth;

    ESVault eTSTAsESVault;
    ESVault eTST2AsESVault;

    function setUp() public virtual override {
        super.setUp();

        address esVaultImpl = address(new ESVault(integrations, modules));

        vm.prank(admin);
        factory.setImplementation(esVaultImpl);

        assetTSTAsSynth = ESynth(address(new ESynth(evc, "Test Synth", "TST")));
        assetTST = TestERC20(address(assetTSTAsSynth));
        assetTST2AsSynth = ESynth(address(new ESynth(evc, "Test Synth 2", "TST2")));
        assetTST2 = TestERC20(address(assetTST2AsSynth));

        eTST = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
        eTST.setIRM(address(new IRMTestDefault()));
        eTSTAsESVault = ESVault(address(eTST));

        // Set the capacity for the vault on the synth
        // assetTSTAsSynth.setCapacity(address(eTST), type(uint128).max);

        eTST2 = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST2), address(oracle), unitOfAccount)));
        eTST2.setIRM(address(new IRMTestDefault()));
        eTST2AsESVault = ESVault(address(eTST2));
        // Set the capacity for the vault on the synth
        // assetTST2AsSynth.setCapacity(address(eTST2), type(uint128).max);
    }
}

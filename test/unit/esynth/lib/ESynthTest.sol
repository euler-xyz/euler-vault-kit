// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../evault/EVaultTestBase.t.sol";
import {ESVault} from "src/ESVault/ESVault.sol";
import {IEVault, IERC20} from "src/EVault/IEVault.sol";
import {IRMTestDefault} from "../../../mocks/IRMTestDefault.sol";
import {ESynth} from "src/ESynth/ESynth.sol";
import {TestERC20} from "../../../mocks/TestERC20.sol";

contract ESynthTest is EVaultTestBase {
    ESynth esynth;
    ESVault eTSTAsESVault;
    address user1;
    address user2;

    function setUp() public virtual override {
        super.setUp();

        address esVaultImpl = address(new ESVault(integrations, modules));
        user1 = vm.addr(1001);
        user2 = vm.addr(1002);
        vm.prank(admin);
        factory.setImplementation(esVaultImpl);

        esynth = ESynth(address(new ESynth(evc, "Test Synth", "TST")));
        assetTST = TestERC20(address(esynth));

        eTST = IEVault(factory.createProxy(true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)));
        eTST.setIRM(address(new IRMTestDefault()));
        eTSTAsESVault = ESVault(address(eTST));
    }
}

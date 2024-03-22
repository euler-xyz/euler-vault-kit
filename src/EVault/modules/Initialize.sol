// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IInitialize, IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {DToken} from "../DToken.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";
import {RevertBytes} from "../shared/lib/RevertBytes.sol";
import {VaultCache} from "../shared/types/VaultCache.sol";
// import {SnapshotStorage} from "../shared/SnapshotStorage.sol";

import "../shared/Constants.sol";
import "../shared/types/Types.sol";

abstract contract InitializeModule is IInitialize, Base, BorrowUtils {
    using TypesLib for uint16;

    uint256 constant INITIAL_INTEREST_ACCUMULATOR = 1e27; // 1 ray
    uint16 constant DEFAULT_INTEREST_FEE = 0.23e4;
    // keccak256(abi.encode(uint256(keccak256("euler.evault.storage.Initialize")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZE_STORAGE = 0xa751f44bd531ee367ee4afe8b302ebe9c90d72d4cb5022352fe2f526c8608b00;

    /// @dev Storage of the Initialize module, implemented on a custom ERC-7201 namespace.
    /// @custom:storage-location erc7201:euler.evault.storage.Initialize
    struct InitializeStorage {
        bool initialized;
    }

    /// @inheritdoc IInitialize
    function initialize(address proxyCreator) public virtual reentrantOK {
        if (initializeStorage().initialized) revert E_Initialized();
        initializeStorage().initialized = true;

        // Validate proxy immutables

        // Calldata should include: signature and abi encoded creator address (4 + 32 bytes), followed by proxy metadata
        if (msg.data.length != 4 + 32 + PROXY_METADATA_LENGTH) revert E_ProxyMetadata();
        (IERC20 asset,,) = ProxyUtils.metadata();
        // Make sure the asset is a contract. Token transfers using a library will not revert if address has no code.
        if (address(asset).code.length == 0) revert E_BadAddress();
        // Other constraints on values should be enforced by product line

        // Create sidecar DToken

        address dToken = address(new DToken());

        // Initialize storage

        VaultData storage _vaultStorage = vaultStorage();

        _vaultStorage.lastInterestAccumulatorUpdate = uint48(block.timestamp);
        _vaultStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;
        _vaultStorage.interestFee = DEFAULT_INTEREST_FEE.toConfigAmount();
        _vaultStorage.creator = _vaultStorage.governorAdmin = _vaultStorage.pauseGuardian = proxyCreator;

        snapshotStorage().reset();

        // Emit logs

        emit EVaultCreated(proxyCreator, address(asset), dToken);
        logMarketStatus(loadMarket(), 0);
    }

    // prevent initialization of the implementation contract
    constructor() {
        initializeStorage().initialized = true;
    }

    function initializeStorage() private view returns (InitializeStorage storage data) {
        assembly {
            data.slot := INITIALIZE_STORAGE
        }
    }
}

contract Initialize is InitializeModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

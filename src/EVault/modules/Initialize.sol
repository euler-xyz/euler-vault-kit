// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IInitialize, IERC20} from "../IEVault.sol";
import {Base} from "../shared/Base.sol";
import {BorrowUtils} from "../shared/BorrowUtils.sol";
import {DToken} from "../DToken.sol";
import {ProxyUtils} from "../shared/lib/ProxyUtils.sol";

import "../shared/Constants.sol";
import "../shared/types/Types.sol";

/// @title InitializeModule
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An EVault module implementing the initialization of the new vault contract
abstract contract InitializeModule is IInitialize, Base, BorrowUtils {
    using TypesLib for uint16;

    uint256 internal constant INITIAL_INTEREST_ACCUMULATOR = 1e27; // 1 ray
    uint16 internal constant DEFAULT_INTEREST_FEE = 0.1e4;

    /// @inheritdoc IInitialize
    function initialize(address proxyCreator) public virtual reentrantOK {
        if (initialized) revert E_Initialized();
        initialized = true;

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

        vaultStorage.lastInterestAccumulatorUpdate = uint48(block.timestamp);
        vaultStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;
        vaultStorage.interestFee = DEFAULT_INTEREST_FEE.toConfigAmount();
        vaultStorage.creator = vaultStorage.governorAdmin = proxyCreator;

        snapshot.reset();

        // Emit logs

        emit EVaultCreated(proxyCreator, address(asset), dToken);
        logVaultStatus(loadVault(), 0);
    }

    // prevent initialization of the implementation contract
    constructor() {
        initialized = true;
    }
}

/// @dev Deployable module contract
contract Initialize is InitializeModule {
    constructor(Integrations memory integrations) Base(integrations) {}
}

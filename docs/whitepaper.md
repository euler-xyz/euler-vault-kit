# Euler Vaults

Dariusz Glowinski, Mick de Graaf, Kasper Pawlowski, Michael Bentley, Doug Hoyte

## Introduction

The Euler Vault system is a re-build of the Euler V1 lending platform with the goal of creating a more modular and composable lending and borrowing platform. Considering the Ethereum ecosystem has advanced since the initial version of the Euler contracts were written, we wanted our re-build to use more conventional and modern patterns, fix some warts, and add some powerful new capabilities along the way.

Several parts of the Euler V1 system have been factored out into a separate project called the [Credit Vault Connector](https://github.com/euler-xyz/euler-cvc/blob/master/docs/whitepaper.md) (CVC), which is an owner-less "public good" contract. The CVC is the core protocol that defines the interactions between collaterals and liabilities, as well as the key pieces needed for constructing an advanced client application, based on our experience. See the CVC whitepaper for full details.

In the CVC model, assets are stored inside of [ERC-4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) vaults. This is an emerging standard for yield-bearing assets that we feel will ultimately become one of the most important token-related standards on Ethereum.

At a high level, the Euler Vaults system is a mechanism for building a type of ERC-4626 vault called an eVault. However, the internal structure has been carefully designed to support what we believe will be the next-generation of on-chain financial products. This whitepaper describes our design and outlines some of the use-cases it enables.


## Contract Architecture

In Euler V1, all storage resided inside a "singleton" contract, and this contract's address was the holder of all non-loaned out assets. The Euler Vaults system takes a more conventional approach where each vault manages its own storage and holds only the token balance it is responsible for.

This separation of storage and assets allows multiple vaults to be created for the same underlying asset, and supports (but does not require) different variants of the implementation code to be installed for different vaults. The separation of storage implies that each vault has its own re-entrancy guard, allowing vaults to be nested -- more on this below.

### EVaultFactory

The `EVaultFactory` contract creates eVaults, which are [beacon proxies](https://eips.ethereum.org/EIPS/eip-1967) that use the factory as the beacon. There can be many factories, and their created eVaults can interact via the CVC, but the Euler DAO will deploy and maintain a factory built on our open and audited codebase, according to its governance.

There are three privileged addresses within the factory:

* `upgradeAdmin`
* `governorAdmin`
* `protocolFeesHolder`

### EVaultProxy

As mentioned, these are beacon proxies and are therefore fully transparent. A couple optimisations have been applied:

* Since the beacon proxy is always the factory, its address is stored as an immutable to avoid a storage load. The `eip1967.proxy.beacon` slot is still populated however, because some block explorers depend on this.
* Some static information that is known at eVault creation time is also embedded as immutable "metadata", and this data is appended onto the end of the calldata when invoking the implementation contract. This saves the implementation from having to load this data from its storage during regular operation.

After creating an `EVaultProxy`, the factory invokes the `initialize()` method on the proxy, which calls the method of the same name on the eVault, and records the address of the created proxy along with caching some of the metadata in its own storage.

### EVault

This is the contract implementation of the EVault itself. Although its ABI contains all the functions exposed by the vault, the sum of all the compiled bytecode for all these functions exceeds Ethereum's contract code size limit. For that reason, some of the code is stored in "static modules". These are effectively the same as solidity libraries, except that they are allowed to access storage and are required to respect the eVault's storage layout.

Functions that are invoked frequently should still reside in the eVault implementation itself so that a `delegatecall` into the static module is avoided. The static module system is very useful for development, since the decision about which module a function should live in, or if it should be in the eVault itself, can be deferred until the finalisation of the contract code. As in Euler V1, modules can import as many utilities as desired, and the compiler will prune unused functions out of the final bytecode for each module.

There is one unfortunate deficiency in the static module system...



RiskManager
Factory and Fees
Liquidation
stop-loss
babies
pricing/oracles
storage in proxies

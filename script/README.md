# Euler Vault Kit helper scripts

## Deployment on a fork

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `ANVIL_PORT=8546` (the default port of the anvil fork)
- `ANVIL_RPC_URL="http://127.0.0.1:$ANVIL_PORT"` (the default address and port of the anvil fork)
- `RPC_URL` (remote endpoint from which the state will be fetched)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments)

### Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up a fork:

```sh
source .env && anvil --port "$ANVIL_PORT" --fork-url "$RPC_URL"
```

After that, deploy the contracts in a different terminal window.

### Peripherals deployment

This command deploys:
- mock price oracle
- mock interest rate model
- lens contract

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentPeripherals --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/Peripherals.json`

### Integrations deployment

This command deploys:
- EVC
- protocol config contract
- balance tracker
- sets up permit2 contract if needed

Inputs:
`script/input/01_Deployment/Integrations.json`

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentIntegrations --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/Integrations.json`

### EVault implementation deployment

This command deploys:
- EVault modules contracts
- EVault implementation contract

Inputs:
`script/input/01_Deployment/EVault.json`

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentEVault --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/EVault.json`

### Factory deployment

This command deploys EVault factory contract.

Inputs:
`script/input/01_Deployment/Factory.json`

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentFactory --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/Factory.json`

### Test Asset deployment

This command:
- deploys ERC20 test assets
- mints deployed tokens to the specified address

Inputs:
`script/input/01_Deployment/Assets.json`

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentAssets --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/Assets.json`

### Vault deployment

This command deploys vault proxies using specified factory.

Inputs:
`script/input/01_Deployment/Vaults.json`

```sh
source .env && forge script script/01_Deployment.s.sol:DeploymentVaults --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/01_Deployment/Vaults.json`

### Test environment deployment

This command deploys multiple vaults and, in needed, test assets.

Inputs:
`script/input/02_DeploymentAll/DeploymentAll.json`

If `vaults` field specified, the script deploys vaults as per specification.
If `vaults` field *NOT* specified, the script deploys test assets first and then deploys corresponding vaults.

```sh
source .env && forge script script/02_DeploymentAll.s.sol:DeploymentAll --rpc-url "$ANVIL_RPC_URL" --broadcast
```

Outputs:
`script/output/02_DeploymentAll/DeploymentAll.json`

## Lens

This script uses lens contract to look up the vault and, if needed, the account info.

Inputs:
`script/input/03_Lens/Lens.json`

If only vault info needed, do not provide the account address when prompted by simply hitting *ENTER*.

```sh
source .env && forge script script/03_Lens.s.sol:Lens --rpc-url "$ANVIL_RPC_URL"
```

Outputs:
`script/output/03_Lens/Vault.json`
`script/output/03_Lens/Account.json`

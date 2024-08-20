Note that for most modules the spec HealthStatusInvariant.spec is used, but for Liquidation,
the spec needs to be split into more cases for performance reasons so it uses LiquidateHealthStatus.spec

Also note that for ETokenCollateralHealthStatus is used to verify functions called on the collateral
EToken contract rather than the vault under test, and UnderlyingTokenHealthStatus is used to verify
functions called on the underlying asset.

To run all of these configurations easily, use certora/scripts/runHealthStatusAllModules.py
Note that for most modules the spec HealthStatusInvariant.spec is used, but for Liquidation,
the spec needs to be split into more cases for performance reasons so it uses LiquidateHealthStatus.spec

To run all of these configurations easily, use certora/scripts/runHealthStatusAllModules.py
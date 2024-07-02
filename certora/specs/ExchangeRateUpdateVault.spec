methods {
}

// This shows the exchange rate is montonicly icnreasing over
// time after calls to update vault
rule exchange_rate_monotonic_update_vault {
    env e;
    uint256 shares;
    // assume no debt socialization
    require !hasDebtSocialization(e); // note not envfree

    // want to show assetsAfter / shares >= assetsBefore / shares
    // but we can skip the division
    uint256 assetsBefore = convertToAssets(e, shares);
    updateVaultExt(e);
    uint256 assetsAfter = convertToAssets(e, shares);

    assert assetsAfter >= assetsBefore;

}
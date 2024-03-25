const et = require('./lib/eTestLib');
const child_process = require("child_process");

// et.testSet({
//     desc: "euler simple lens",
//     preActions: ctx => [
//         { action: 'cb', cb: async () => {
//             // deploy mock simple lens

//             let gitCommit = ethers.utils.hexZeroPad('0x' + child_process.execSync('git rev-parse HEAD').toString().trim(), 32);

//             let SimpleLens = await ethers.getContractFactory('EulerSimpleLens');
            
//             ctx.contracts.simpleLens = await (await SimpleLens.deploy(gitCommit, ctx.contracts.euler.address)).deployed();
//             ctx.gitCommit = gitCommit;
//         }}
//     ]
// })



// .test({
//     desc: "set state variables upon deployment",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             et.expect(await ctx.contracts.simpleLens.euler()).to.equal(ctx.contracts.euler.address);
//             et.expect(await ctx.contracts.simpleLens.moduleGitCommit()).to.equal(ctx.gitCommit);

//             const marketsModule = await ctx.contracts.euler.moduleIdToProxy(et.moduleIds.MARKETS);
//             const execModule = await ctx.contracts.euler.moduleIdToProxy(et.moduleIds.EXEC);

//             et.expect(await ctx.contracts.simpleLens.markets()).to.equal(marketsModule);
//             et.expect(await ctx.contracts.simpleLens.exec()).to.equal(execModule);
//         }},
//     ],
// })



// .test({
//     desc: "get eVault address for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let eVaultAddress = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToEVault(underlying)).to.equal(eVaultAddress);
//         }},
//     ],
// })



// .test({
//     desc: "get dToken address for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let dTokenAddress = await ctx.contracts.markets.underlyingToDToken(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToDToken(underlying)).to.equal(dTokenAddress);
//         }},
//     ],
// })



// .test({
//     desc: "get pToken address for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let pTokenAddress = await ctx.contracts.markets.underlyingToPToken(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToPToken(underlying)).to.equal(pTokenAddress);
//             et.expect(await ctx.contracts.simpleLens.underlyingToPToken(underlying)).to.equal(et.AddressZero);

//             await ctx.contracts.markets.activatePToken(underlying);
//             et.expect(await ctx.contracts.simpleLens.underlyingToPToken(underlying)).to.not.equal(et.AddressZero);
//         }},
//     ],
// })



// .test({
//     desc: "get eVault, dToken, and pToken in a single call for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let pTokenAddress = await ctx.contracts.markets.underlyingToPToken(underlying);
//             let dTokenAddress = await ctx.contracts.markets.underlyingToDToken(underlying);
//             let eVaultAddress = await ctx.contracts.riskManagers.riskManagerCore.getMarketByUnderlying(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToInternalTokens(underlying)).to.deep.equal([eVaultAddress, dTokenAddress, pTokenAddress]);
//         }},
//     ],
// })



// .test({
//     desc: "get asset configuration for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let assetConfig = await ctx.contracts.markets.underlyingToAssetConfig(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToAssetConfig(underlying)).to.deep.equal(assetConfig);

//             await ctx.setMarketConfigRMC(underlying, { collateralFactor: 0.2, });

//             assetConfig = await ctx.contracts.markets.underlyingToAssetConfig(underlying);

//             et.expect(await ctx.contracts.simpleLens.underlyingToAssetConfig(underlying)).to.deep.equal(assetConfig);

//             et.expect(assetConfig.collateralFactor).to.equal(Math.floor(0.2 * 1e4));
//         }},
//     ],
// })



// .test({
//     desc: "get interest rate model for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let irm = await ctx.contracts.riskManagers.riskManagerCore.interestRateModel(underlying);

//             et.expect(await ctx.contracts.simpleLens.interestRateModel(underlying)).to.equal(irm);

//             const irmZero = 2000001;

//             await ctx.setInterestRateModel(underlying, irmZero, Buffer.from(""));
            
//             et.expect(await ctx.contracts.simpleLens.interestRateModel(underlying)).to.equal(irmZero);
//         }},
//     ],
// })



// .test({
//     desc: "get interest accumulator for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let accumulator = await ctx.contracts.markets.interestAccumulator(underlying);

//             et.expect(await ctx.contracts.simpleLens.interestAccumulator(underlying)).to.equal(accumulator);
//         }},
//     ],
// })



// .test({
//     desc: "get reserve fee for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let reserveFee = await ctx.contracts.markets.reserveFee(underlying);

//             et.expect(await ctx.contracts.simpleLens.reserveFee(underlying)).to.equal(reserveFee);

//             const newFee = Math.floor(0.01 * 1e4);

//             // set reserve fee and retrieve new value from simple lens
//             await ctx.setInterestFee(underlying, newFee);

//             et.expect(await ctx.contracts.simpleLens.reserveFee(underlying)).to.equal(newFee);
//         }},
//     ],
// })



// .test({
//     desc: "get pricing config for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let pricingConfig = await ctx.contracts.markets.getPricingConfig(underlying);

//             et.expect(await ctx.contracts.simpleLens.getPricingConfig(underlying)).to.deep.equal(pricingConfig);
//             et.expect(pricingConfig.pricingType).to.equal(2);
//             et.expect(pricingConfig.pricingParameters).to.equal(3000);
//             et.expect(pricingConfig.pricingForwarded).to.equal(et.AddressZero);
//         }},
//     ],
// })



// .test({
//     desc: "get interest rates for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             // zero interest rates for underlying asset upon deployment and no supply or utilisation
//             let interestRates = await ctx.contracts.simpleLens.interestRates(ctx.contracts.tokens.TST2.address);
//             et.equals(interestRates.borrowSPY, 0);
//             et.equals(interestRates.borrowAPY, 0);
//             et.equals(interestRates.supplyAPY, 0);

//             // after initial supply and no utilisation
//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));

//             await ctx.contracts.tokens.TST2.connect(ctx.wallet3).approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.markets.connect(ctx.wallet3).enterMarket(0, ctx.contracts.eVaults.eTST2.address);
//             await ctx.contracts.tokens.TST2.mint(ctx.wallet3.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST2.connect(ctx.wallet3).deposit(0, et.eth(10));

//             interestRates = await ctx.contracts.simpleLens.interestRates(ctx.contracts.tokens.TST2.address);
//             et.equals(interestRates.borrowSPY, 0);
//             et.equals(interestRates.borrowAPY, 0);
//             et.equals(interestRates.supplyAPY, 0);

//             // after supply and utilisation
//             await ctx.contracts.eVaults.eTST2.borrow(0, et.eth(1));

//             interestRates = await ctx.contracts.simpleLens.interestRates(ctx.contracts.tokens.TST2.address);
//             et.equals(interestRates.borrowAPY / 1e27, 0.019, 0.01);
//             et.equals(interestRates.supplyAPY / 1e27, 0.0014, 0.0001);
//         }},
//     ],
// })

// .test({
//     desc: "get underlying asset name and symbol",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             const tokenInfo = await ctx.contracts.simpleLens.getTokenInfo(underlying);
//             const tokenName = tokenInfo[0];
//             const tokenSymbol = tokenInfo[1];
            
//             et.expect(tokenName).to.equal("Test Token");
//             et.expect(tokenSymbol).to.equal("TST");
//         }},
//     ],
// })


// .test({
//     desc: "get euler allowance for specified underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             await (await ctx.contracts.tokens.TST.connect(ctx.wallet2).approve(ctx.contracts.euler.address, et.MaxUint256)).wait();

//             let allowance = await ctx.contracts.tokens.TST.allowance(ctx.wallet2.address, ctx.contracts.euler.address);

//             et.expect(allowance).to.equal(await ctx.contracts.simpleLens.getEulerAccountAllowance(underlying, ctx.wallet2.address));
//             et.expect(et.MaxUint256).to.equal(await ctx.contracts.simpleLens.getEulerAccountAllowance(underlying, ctx.wallet2.address));
//         }},
//     ],
// })



// .test({
//     desc: "should return zero euler allowance for zero address",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             await (await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256)).wait();

//             const allowance = await ctx.contracts.tokens.TST.allowance(et.AddressZero, ctx.contracts.euler.address);

//             et.expect(await ctx.contracts.simpleLens.getEulerAccountAllowance(underlying, et.AddressZero)).to.equal(allowance);
//             et.expect(await ctx.contracts.simpleLens.getEulerAccountAllowance(underlying, et.AddressZero)).to.equal(0);
//         }},
//     ],
// })



// .test({
//     desc: "get twap, twapPeriod, currPrice in a single call for underlying asset",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;
//             let fullPrice = await ctx.contracts.exec.getPriceFull(underlying);

//             et.expect(await ctx.contracts.simpleLens.getPriceFull(underlying)).to.deep.equal(fullPrice);
//             et.expect(fullPrice.currPrice).to.equal(et.eth(1e18));

//             await ctx.updateUniswapPrice('TST/WETH', '0.03');

//             fullPrice = await ctx.contracts.exec.getPriceFull(underlying);

//             et.expect(await ctx.contracts.simpleLens.getPriceFull(underlying)).to.deep.equal(fullPrice);
//             et.expect(fullPrice.currPrice).to.equal(et.eth('0.03'));
//         }},
//     ],
// })



// .test({
//     desc: "get pToken balance before wrapping",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             await ctx.contracts.markets.activatePToken(underlying);
//             ctx.contracts.pTokens = {};
//             let pTokenAddr = await ctx.contracts.markets.underlyingToPToken(underlying);
//             ctx.contracts.pTokens['pTST'] = await ethers.getContractAt('PToken', pTokenAddr);

//             let pTokenBalance = await ctx.contracts.simpleLens.getPTokenBalance(underlying, ctx.wallet.address);
//             et.expect(pTokenBalance).to.equal(0);
//         }},
//     ],
// })


// .test({
//     desc: "get zero eVault balance before deposit",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             let eVaultBalance = await ctx.contracts.simpleLens.getEVaultBalance(underlying, ctx.wallet.address);
//             et.expect(eVaultBalance).to.equal(0);
//         }},
//     ],
// })



// .test({
//     desc: "get zero dToken balance before borrow",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             let dTokenBalance = await ctx.contracts.simpleLens.getDTokenBalance(underlying, ctx.wallet.address);
//             et.expect(dTokenBalance).to.equal(0);
//         }},
//     ],
// })



// .test({
//     desc: "get dToken balance after borrow",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));
            
//             await ctx.contracts.tokens.TST2.connect(ctx.wallet3).approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.markets.connect(ctx.wallet3).enterMarket(0, ctx.contracts.eVaults.eTST2.address);
//             await ctx.contracts.tokens.TST2.mint(ctx.wallet3.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST2.connect(ctx.wallet3).deposit(0, et.eth(10));

//             // ctx.wallet borrows TST2 with TST collateral
//             await ctx.contracts.eVaults.eTST2.borrow(0, et.eth(1));
//             let dTokenBalance = await ctx.contracts.simpleLens.getDTokenBalance(ctx.contracts.tokens.TST2.address, ctx.wallet.address);
//             et.expect(await ctx.contracts.eVaults.eTST2.debtOf(ctx.wallet.address)).to.equal(dTokenBalance);
//         }},
//     ],
// })

// .test({
//     desc: "get account status before borrow",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let accountStatus = await ctx.contracts.simpleLens.getAccountStatus(ctx.wallet.address);
//             let liquidity = await ctx.contracts.exec.callStatic.liquidity(ctx.wallet.address);

//             et.expect(accountStatus.healthScore).to.equal(et.MaxUint256);
//             et.expect(accountStatus.liabilityValue).to.equal(0);
//             et.expect(accountStatus.collateralValue).to.equal(0);

//             et.expect(liquidity.liabilityValue).to.equal(0);
//             et.expect(liquidity.collateralValue).to.equal(0);

//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));
            
//             accountStatus = await ctx.contracts.simpleLens.getAccountStatus(ctx.wallet.address);
//             liquidity = await ctx.contracts.exec.callStatic.liquidity(ctx.wallet.address);
//             et.expect(liquidity.collateralValue).to.equal(accountStatus.collateralValue);
//             et.expect(liquidity.liabilityValue).to.equal(accountStatus.liabilityValue);
//         }},
//     ],
// })



// .test({
//     desc: "get account status after borrow",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));
            
//             await ctx.contracts.tokens.TST2.connect(ctx.wallet3).approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.markets.connect(ctx.wallet3).enterMarket(0, ctx.contracts.eVaults.eTST2.address);
//             await ctx.contracts.tokens.TST2.mint(ctx.wallet3.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST2.connect(ctx.wallet3).deposit(0, et.eth(10));

//             let accountStatus = await ctx.contracts.simpleLens.getAccountStatus(ctx.wallet.address);
//             et.expect(accountStatus.healthScore).to.equal(et.MaxUint256)

//             // ctx.wallet borrows TST2 with TST collateral
//             await ctx.contracts.eVaults.eTST2.borrow(0, et.eth(2));

//             accountStatus = await ctx.contracts.simpleLens.getAccountStatus(ctx.wallet.address);
//             const liquidity = await ctx.contracts.exec.callStatic.liquidity(ctx.wallet.address);
            
//             et.expect(liquidity.collateralValue).to.equal(accountStatus.collateralValue);
//             et.expect(liquidity.liabilityValue).to.equal(accountStatus.liabilityValue);
            
//             let targetHealth = (await ctx.contracts.liquidation.TARGET_HEALTH()) / 1e18;
            
//             et.equals(accountStatus.collateralValue / accountStatus.liabilityValue, targetHealth, 0.25);
//         }},
//     ],
// })



// .test({
//     desc: "get total supply and debts",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));
            
//             await ctx.contracts.tokens.TST2.connect(ctx.wallet3).approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.markets.connect(ctx.wallet3).enterMarket(0, ctx.contracts.eVaults.eTST2.address);
//             await ctx.contracts.tokens.TST2.mint(ctx.wallet3.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST2.connect(ctx.wallet3).deposit(0, et.eth(10));

//             // ctx.wallet borrows TST2 with TST collateral
//             await ctx.contracts.eVaults.eTST2.borrow(0, et.eth(1));
            
//             const supplyAndDebts_TST = await ctx.contracts.simpleLens.getTotalSupplyAndDebts(ctx.contracts.tokens.TST.address);
//             const supplyAndDebts_TST2 = await ctx.contracts.simpleLens.getTotalSupplyAndDebts(ctx.contracts.tokens.TST2.address);

//             et.expect(supplyAndDebts_TST.poolSize).to.equal(et.eth(10));
//             et.equals(supplyAndDebts_TST.totalBalances, et.eth(10), et.DefaultReserve);
//             et.expect(supplyAndDebts_TST.totalBorrows).to.equal(0);
//             et.expect(supplyAndDebts_TST.accumulatedFees).to.equal(999999);

//             et.expect(supplyAndDebts_TST2.poolSize).to.equal(et.eth(9));
//             et.equals(supplyAndDebts_TST2.totalBalances, et.eth(10), et.DefaultReserve);
//             et.expect(supplyAndDebts_TST2.totalBorrows).to.equal(et.eth(1));
//             et.expect(supplyAndDebts_TST2.accumulatedFees).to.equal(999999);
//         }},
//     ],
// })



// .test({
//     desc: "get eVault balance after initial deposit",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             await ctx.contracts.tokens.TST.approve(ctx.contracts.euler.address, et.MaxUint256);
//             await ctx.contracts.evc.enableCollateral(0, ctx.contracts.eVaults.eTST.address);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.eVaults.eTST.deposit(0, et.eth(10));
            
//             let eVaultBalance = await ctx.contracts.simpleLens.getEVaultBalance(underlying, ctx.wallet.address);
//             et.equals(eVaultBalance, await ctx.contracts.eVaults.eTST.balanceOf(ctx.wallet.address), et.DefaultReserve);
//         }},
//     ],
// })



// .test({
//     desc: "get pToken balance after wrapping",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             await ctx.contracts.markets.activatePToken(underlying);
//             ctx.contracts.pTokens = {};
//             let pTokenAddr = await ctx.contracts.markets.underlyingToPToken(underlying);
//             ctx.contracts.pTokens['pTST'] = await ethers.getContractAt('PToken', pTokenAddr);

//             await ctx.contracts.tokens.TST.approve(pTokenAddr, et.MaxUint256);
//             await ctx.contracts.tokens.TST.mint(ctx.wallet.address, et.eth(100));
//             await ctx.contracts.pTokens['pTST'].wrap(et.eth(10));
            
//             pTokenBalance = await ctx.contracts.simpleLens.getPTokenBalance(underlying, ctx.wallet.address);
//             et.expect(await ctx.contracts.pTokens['pTST'].balanceOf(ctx.wallet.address)).to.equal(pTokenBalance);
//         }},
//     ],
// })



// .test({
//     desc: "should not return any entered market if not entered by account",
//     actions: ctx => [
//         { action: 'cb', cb: async () => {
//             let underlying = ctx.contracts.tokens.TST.address;

//             et.expect([]).to.deep.equal(await ctx.contracts.simpleLens.getEnteredMarkets(ctx.wallet2.address));

//             await ctx.contracts.markets.connect(ctx.wallet2).enterMarket(0, underlying);

//             et.expect(await ctx.contracts.simpleLens.getEnteredMarkets(ctx.wallet2.address)).to.deep.equal([underlying]);
//         }},
//     ],
// })


// .run();

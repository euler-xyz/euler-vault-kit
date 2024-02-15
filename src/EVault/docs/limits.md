## amounts

`uint112`

* Maximum sane amount (result of balanceOf) for external tokens
* Uniswap2 limits token amounts to this
* Underlying for custom types Assets and Shares
* Maximum sane amount decreased by 1 to account for virtual share / asset
* Spec: For an 18 decimal token, more than a million billion tokens (1e15)

## small amounts

`uint96`

* For holding amounts that we don't expect to get quite as large, in particular reserve balances
* Can pack together with an address in a single slot
* Underlying for custom type Fees
* Spec: For an 18 decimal token, more than a billion tokens (1e9)

## debt amounts

`uint144`

* Maximum sane amount for debts
* Packs together with an amount in a single storage slot
* Underlying for custom type Owed
* Spec: Should hold the maximum possible amount (uint112) but scaled by another 9 decimal places (for the internal debt precision)
  * Actual: 2e16

## interestRate

`uint72`

* "Second Percent Yield"
* Fraction scaled by 1e27
  * Example: `10% APR = 1e27 * 0.1 / (86400*365) = 1e27 * 0.000000003170979198376458650 = 3170979198376458650`
* Spec: Should hold max allowed interest rate (500% APR)
      -> 2^72
      ~= 4.72237e+21
      -> (5 * 1e27) / (365.2425 * 86400)
      ~= 1.58444e+20

## interestAccumulator

`uint256`

* Starts at 1e27, multiplied by (1e27 + interestRate) every second
* Spec: 100% APR for 100 years
      -> 2^256
      ~= 1.1579208923e+77
      -> 10^27 * (1 + (100/100 / (86400*365)))^(86400*365*100)
      ~= 2.6881128798e+70


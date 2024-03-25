const ethers = require('ethers');
const bn = require('bignumber.js');

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 })



function ratioToSqrtPriceX96(a, b) {
    return ethers.BigNumber.from(
               new bn(a.toString())
               .div(b.toString())
               .sqrt()
               .multipliedBy(new bn(2).pow(96))
               .integerValue(3)
               .toString()
           );
}

function sqrtPriceX96ToPrice(a, invert) {
    let c1e18 = ethers.BigNumber.from('10').pow(18);
    let scale = ethers.BigNumber.from(2).pow(96*2).div(c1e18);
    a = ethers.BigNumber.from(a);
    a = a.mul(a).div(scale);
    if (invert) a = c1e18.mul(c1e18).div(a);
    return new bn(a.toString()).div('1e18').toString();
}


module.exports = {
    ratioToSqrtPriceX96,
    sqrtPriceX96ToPrice,
};

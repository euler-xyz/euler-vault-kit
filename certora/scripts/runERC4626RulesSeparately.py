import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')

rule_names = [
    "conversionOfZero",
    "convertToAssetsWeakAdditivity",
    "convertToSharesWeakAdditivity",
    "conversionWeakMonotonicity",
    "conversionWeakIntegrity",
    "convertToCorrectness",
    "depositMonotonicity",
    "zeroDepositZeroShares",
    "assetsMoreThanSupply",
    "noAssetsIfNoSupply",
    "noSupplyIfNoAssets",
    "totalSupplyIsSumOfBalances",
    "totalsMonotonicity",
    "underlyingCannotChange",
    "dustFavorsTheHouse",
    "dustFavorsTheHouseAssets",
    "vaultSolvency",
    "redeemingAllValidity",
    "contributingProducesShares",
    "onlyContributionMethodsReduceAssets",
    "reclaimingProducesAssets"
]

for name in rule_names:
    args = parser.parse_args()
    script = "certora/conf/VaultERC4626.conf"
    command = f"certoraRun {script} --rule \"{name}\" --msg \"{name} : {args.batchMsg}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)
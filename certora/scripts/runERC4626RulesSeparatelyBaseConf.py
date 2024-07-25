import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')

# The commented out ones are the ones that need a special config file.
# Those can be run easily by running runERC4626RulesSplitConfs.py
rule_names = [
    # "assetsMoreThanSupply",
    "contributingProducesShares",
    "conversionOfZero",
    "conversionWeakIntegrity",
    "conversionWeakMonotonicity",
    # "convertToAssetsWeakAdditivity",
    # "convertToSharesWeakAdditivity",
    # "depositMonotonicity",
    # "dustFavorsTheHouse",
    # "dustFavorsTheHouseAssets",
    # "noAssetsIfNoSupply",
    # "noSupplyIfNoAssets",
    # "onlyContributionMethodsReduceAssets",
    "reclaimingProducesAssets",
    "redeemingAllValidity",
    "totalSupplyIsSumOfBalances",
    # "totalsMonotonicity",
    "zeroDepositZeroShares",
    "underlyingCannotChange",
    # "vaultSolvency",
]

for name in rule_names:
    args = parser.parse_args()
    script = "certora/conf/ERC4626Split/VaultERC4626.conf"
    command = f"certoraRun {script} --rule \"{name}\" --msg \"{name} : {args.batchMsg}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)
import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')

rule_confs = {
    "conversionOfZero": "BaseERC4626.conf",
    "convertToAssetsWeakAdditivity": "BaseERC4626.conf",
    "convertToSharesWeakAdditivity": "BaseERC4626.conf" ,
    "conversionWeakMonotonicity": "BaseERC4626.conf",
    "conversionWeakIntegrity": "BaseERC4626.conf",
    "convertToCorrectness": "BaseERC4626.conf",
    "depositMonotonicity": "BaseERC4626.conf",
    "zeroDepositZeroShares": "BaseERC4626.conf",
    "assetsMoreThanSupply": "BaseERC4626.conf",
    "noAssetsIfNoSupply": "BaseERC4626.conf",
    "noSupplyIfNoAssets": "BaseERC4626.conf",
    "totalSupplyIsSumOfBalances": "BaseERC4626.conf",
    "totalsMonotonicity": "BaseERC4626.conf",
    "underlyingCannotChange": "BaseERC4626.conf",
    "dustFavorsTheHouse": "BaseERC4626.conf",
    "vaultSolvency": "BaseERC4626.conf",
    "redeemingAllValidity": "BaseERC4626.conf",
    "contributingProducesShares": "BaseERC4626.conf",
    "onlyContributionMethodsReduceAssets": "BaseERC4626.conf",
    "reclaimingProducesAssets": "BaseERC4626.conf"
}

for name in rule_confs.keys():
    args = parser.parse_args()
    script = f"certora/conf/ERC4626Rules/{rule_confs[name]}"
    command = f"certoraRun {script} --rule \"{name}\" --msg \"{name} : {args.batchMsg}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)
import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')

erc4626_confs = {
    "",
    "-assetsMoreThanSupply",
    "-convertToAssetsWeakAdditivity",
    "-convertToSharesWeakAdditivity",
    "-depositMonotonicity",
    "-dustFavorsTheHouse",
    "-dustFavorsTheHouseAssets",
    "-noAssetsIfNoSupply",
    "-noSupplyIfNoAssets",
    "-onlyContributionMethodsReduce",
    "-totalsMonotonicity",
    "-vaultSolvency-most",
    "-vaultSolvency-redeem",
    "-vaultSolvency-withdraw",
    # In case the invariant times out for withdraw
    "-vaultSolvency-withdraw-as-rule"
}

for name in erc4626_confs:
    args = parser.parse_args()
    script = f"certora/conf/ERC4626Split/VaultERC4626{name}.conf"
    command = f"certoraRun {script} --msg \"{name} : {args.batchMsg}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)


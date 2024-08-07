import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')
args = parser.parse_args()

hs_confs = [
    # "BalanceForwarder",
    "Borrowing",
    # "Governance",
    # "Liquidation",
    # "RiskManager",
    # "Token",
    # "Vault"
]

def runAllConfs(rule):
  for conf in hs_confs:
      script = f"certora/conf/exchangeRate/{conf}ER.conf"
      command = f"certoraRun {script} --rule {rule} --msg \"{conf} : {args.batchMsg}\""
      print(f"runing {command}")
      subprocess.run(command, shell=True)


vaultSplitMethods = [
  #"deposit(uint256,address)",
  # "mint(uint256,address)",
  "redeem(uint256,address,address)",
  "withdraw(uint256,address,address)"
]

def runVaultSplit(rule):
  for method in vaultSplitMethods:
      script = f"certora/conf/exchangeRate/VaultER.conf"
      command = f"certoraRun {script} --rule {rule} --method \"{method}\" --msg \"{method} : {args.batchMsg}\""
      print(f"runing {command}")
      subprocess.run(command, shell=True)

runAllConfs("exchange_rate_monotonic")
runVaultSplit("exchange_rate_monotonic")
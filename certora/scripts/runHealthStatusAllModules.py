import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')
args = parser.parse_args()

hs_confs = [
    "BalanceForwarder",
    "Borrowing",
    "Governance",
    "Initialize",
    "Liquidation",
    "Token",
    "Vault"
]

for conf in hs_confs:
    script = f"certora/conf/healthStatus/{conf}HealthStatus.conf"
    command = f"certoraRun {script} --msg \"{conf} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)

borrow_separate_methods = [
  "borrow(uint256,address)",
  "pullDebt(uint256,address)",
  "repayWithShares(uint256,address)",
  "repay(uint256,address)",
]

for method in borrow_separate_methods:
    script = f"certora/conf/healthStatus/BorrowingHealthStatus.conf"
    command = f"certoraRun {script} --msg \"Borrow.{method} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\" --method \"{method}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)

vault_separate_methods = [
  "redeem(uint256,address,address)",
  "withdraw(uint256,address,address)"
]

for method in vault_separate_methods:
    script = f"certora/conf/healthStatus/VaultHealthStatus.conf"
    command = f"certoraRun {script} --msg \"Vault.{method} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\" --method \"{method}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)

liquidate_cases = [
    "liquidateAccountsStayHealthy_liquidator_no_debt_socialization",
    "liquidateAccountsStayHealthy_liquidator_with_debt_socialization",
    "liquidateAccountsStayHealthy_not_violator",
    "liquidateAccountsStayHealthy_account_cur_contract"
]

for rule in liquidate_cases:
    script = f"certora/conf/healthStatus/LiquidateHealthStatus.conf"
    command = f"certoraRun {script} --msg \"Liquidate case: {rule} : {args.batchMsg}\" --rule \"{rule}\""
    print(f"runing {command}")
    subprocess.run(command, shell=True)

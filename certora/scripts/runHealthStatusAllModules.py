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
    "Vault",
    "ETokenCollateral",
    "UnderlyingToken"
]

def runModules():
  for conf in hs_confs:
      script = f"certora/conf/healthStatus/{conf}HealthStatus.conf"
      command = f"certoraRun {script} --msg \"{conf} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\""
      print(f"runing {command}")
      subprocess.run(command, shell=True)

# List includes all public non-view methods aside from setLTV, clearLTV which
# are out of scope for the holy grail rule.
gov_separate_methods = [
    "convertFees()",
    "setGovernorAdmin(address)",
    "setFeeReceiver(address)",
    "setMaxLiquidationDiscount(uint16)",
    "setLiquidationCoolOffTime(uint16)",
    "setInterestRateModel(address)",
    "setHookConfig(address,uint32)",
    "setConfigFlags(uint32)",
    "setCaps(uint16,uint16)",
    "setInterestFee(uint16)"
]

def runGovSeparately():
    for method in gov_separate_methods:
        script = f"certora/conf/healthStatus/GovernanceHealthStatus.conf"
        command = f"certoraRun {script} --msg \"Governance.{method} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\" --method \"{method}\""
        print(f"runing {command}")
        subprocess.run(command, shell=True)

# List includes all public non-view methods 
token_separate_methods = [
    "transfer(address,uint256)",
    "transferFromMax(address,address)",
    "transferFrom(address,address,uint256)",
    "approve(address,uint256)"
]

def runTokenSeparately():
    for method in token_separate_methods:
        script = f"certora/conf/healthStatus/TokenHealthStatus.conf"
        command = f"certoraRun {script} --msg \"Token.{method} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\" --method \"{method}\""
        print(f"runing {command}")
        subprocess.run(command, shell=True)

borrow_separate_methods = [
  "borrow(uint256,address)",
  "pullDebt(uint256,address)",
  "repayWithShares(uint256,address)",
  "repay(uint256,address)",
]

def runBorrowSeparately():
    for method in borrow_separate_methods:
        script = f"certora/conf/healthStatus/BorrowingHealthStatus.conf"
        command = f"certoraRun {script} --msg \"Borrow.{method} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\" --method \"{method}\""
        print(f"runing {command}")
        subprocess.run(command, shell=True)

# Includes all public non-view methods of the vault
vault_separate_methods = [
  # Initially just the first two timed out unless run separately,
  # but now all will run into memory issues unless we run separately
  # "redeem(uint256,address,address)",
  # "withdraw(uint256,address,address)",
  "deposit(uint256,address)",
  "mint(uint256,address)",
  "withdraw(uint256,address,address)",
  "redeem(uint256,address,address)",
  "skim(uint256,address)",
]

def runVaultSeparately():
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

def runLiquidateCases():
    for rule in liquidate_cases:
        script = f"certora/conf/healthStatus/LiquidateHealthStatus.conf"
        command = f"certoraRun {script} --msg \"Liquidate case: {rule} : {args.batchMsg}\" --rule \"{rule}\""
        print(f"runing {command}")
        subprocess.run(command, shell=True)

runModules()
runGovSeparately()
runTokenSeparately()
runBorrowSeparately()
runVaultSeparately()
runLiquidateCases()
import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('-M', '--batchMsg', metavar='M', type=str, nargs='?',
                    default='',
                    help='a message for all the jobs')

hs_confs = [
    # "BalanceForwarder",
    # "Borrowing",
    "Governance",
    # "Initialize",
    # "Liquidation",
    # "Token",
    # "Vault"
]

for conf in hs_confs:
    args = parser.parse_args()
    script = f"certora/conf/healthStatus/{conf}HealthStatus.conf"
    commands = [
        f"certoraRun {script} --msg \"{conf} : {args.batchMsg}\" --rule \"accountsStayHealthy\"",
        f"certoraRun {script} --msg \"{conf} : {args.batchMsg}\" --rule \"accountsStayHealthy_strategy\""
    ]
    for command in commands:
        print(f"runing {command}")
        subprocess.run(command, shell=True)
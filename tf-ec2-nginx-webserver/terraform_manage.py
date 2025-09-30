#!/usr/bin/env python3
import argparse
import subprocess
import logging
import datetime
import sys
import json
from prettytable import PrettyTable

# -------------------
# Setup logging
# -------------------
timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
logfile = f"terraform_{timestamp}.log"

logging.basicConfig(
    filename=logfile,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)

CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
NC = "\033[0m"

def log(msg):
    print(f"{CYAN}{msg}{NC}")
    logging.info(msg)

def run_cmd(cmd, capture=False):
    """Run shell commands safely"""
    try:
        if capture:
            return subprocess.check_output(cmd, shell=True, text=True).strip()
        else:
            subprocess.run(cmd, shell=True, check=True)
    except subprocess.CalledProcessError:
        return "" if capture else None

# -------------------
# Terraform Functions
# -------------------
def select_workspace(workspace):
    existing = run_cmd("terraform workspace list", capture=True)
    if workspace in existing:
        run_cmd(f"terraform workspace select {workspace}")
    else:
        run_cmd(f"terraform workspace new {workspace}")
    log(f"🌍 Using workspace: {workspace}")

def run_terraform(workspace, action):
    log("🚀 Initializing Terraform...")
    run_cmd("terraform init -input=false")

    log("🧹 Formatting Terraform files...")
    run_cmd("terraform fmt -recursive")

    log("✅ Validating Terraform code...")
    run_cmd("terraform validate")

    if action == "apply":
        log("📜 Creating Terraform plan...")
        run_cmd("terraform plan -out=tfplan -input=false")

        log("⚡ Applying Terraform changes...")
        run_cmd("terraform apply -input=false -auto-approve tfplan")

        run_cmd("rm -f tfplan")
        log(f"🎉 Apply completed successfully in {workspace}!")
        validate_resources(destroy=False)

    elif action == "destroy":
        log(f"🔥 Destroying infrastructure in {workspace}...")
        run_cmd("terraform destroy -auto-approve")
        log(f"✅ Destroy completed in {workspace}!")
        validate_resources(destroy=True)
    else:
        log(f"❌ Unknown action: {action} (use apply/destroy)")
        sys.exit(1)

# -------------------
# AWS Validation
# -------------------
def validate_resources(destroy=False):
    log("🔍 Validating AWS resources with AWS CLI...")

    table = PrettyTable()
    table.field_names = ["Resource Type", "Resource Name/ID", "Status"]

    # ---- EC2 Instances ----
    try:
        ec2s = json.loads(run_cmd("aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output json", capture=True))
        ec2s = sum(ec2s, [])
        if not destroy and ec2s:
            for inst in ec2s:
                table.add_row(["EC2", inst[0], f"{GREEN}✅ {inst[1]}{NC}"])
        else:
            table.add_row(["EC2", "Expected Instance", f"{RED}❌ Deleted{NC}"])
    except Exception:
        table.add_row(["EC2", "Expected Instance", f"{RED}❌ Deleted{NC}"])

    # ---- VPCs ----
    try:
        vpcs = json.loads(run_cmd("aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,State]' --output json", capture=True))
        if not destroy and vpcs:
            for vpc in vpcs:
                table.add_row(["VPC", vpc[0], f"{GREEN}✅ {vpc[1]}{NC}"])
        else:
            table.add_row(["VPC", "Expected VPC", f"{RED}❌ Deleted{NC}"])
    except Exception:
        table.add_row(["VPC", "Expected VPC", f"{RED}❌ Deleted{NC}"])

    # ---- Subnets ----
    try:
        subnets = json.loads(run_cmd("aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,State]' --output json", capture=True))
        if not destroy and subnets:
            for subnet in subnets:
                table.add_row(["Subnet", subnet[0], f"{GREEN}✅ {subnet[1]}{NC}"])
        else:
            table.add_row(["Subnet", "Expected Subnet", f"{RED}❌ Deleted{NC}"])
    except Exception:
        table.add_row(["Subnet", "Expected Subnet", f"{RED}❌ Deleted{NC}"])

    # ---- Security Groups ----
    try:
        sgs = json.loads(run_cmd("aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName]' --output json", capture=True))
        if not destroy and sgs:
            for sg in sgs:
                table.add_row(["SecurityGroup", f"{sg[0]} ({sg[1]})", f"{GREEN}✅ Active{NC}"])
        else:
            table.add_row(["SecurityGroup", "Expected SG", f"{RED}❌ Deleted{NC}"])
    except Exception:
        table.add_row(["SecurityGroup", "Expected SG", f"{RED}❌ Deleted{NC}"])

    # ---- Internet Gateways ----
    try:
        igws = json.loads(run_cmd("aws ec2 describe-internet-gateways --query 'InternetGateways[*].InternetGatewayId' --output json", capture=True))
        if not destroy and igws:
            for igw in igws:
                table.add_row(["InternetGateway", igw, f"{GREEN}✅ Attached{NC}"])
        else:
            table.add_row(["InternetGateway", "Expected IGW", f"{RED}❌ Deleted{NC}"])
    except Exception:
        table.add_row(["InternetGateway", "Expected IGW", f"{RED}❌ Deleted{NC}"])

    print(table)

# -------------------
# Main Flow
# -------------------
def main():
    parser = argparse.ArgumentParser(description="Terraform Automation Script with AWS Validation")
    parser.add_argument("workspace", nargs="?", default="dev", help="Terraform workspace (default: dev)")
    parser.add_argument("action", nargs="?", default="apply", choices=["apply", "destroy"], help="Terraform action (default: apply)")
    args = parser.parse_args()

    log("🚧 Starting Terraform automation...")
    select_workspace(args.workspace)
    run_terraform(args.workspace, args.action)

if __name__ == "__main__":
    main()



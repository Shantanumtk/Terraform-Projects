#!/bin/bash
# Advanced Terraform Automation Script
# Author: Shantanu

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

# -------------------------
# Usage
# ./terraform.sh [workspace] [action]
#
# Examples:
#   ./terraform.sh                # defaults to dev apply
#   ./terraform.sh dev apply      # apply infra in dev
#   ./terraform.sh prod apply     # apply infra in prod
#   ./terraform.sh dev destroy    # destroy infra in dev
#   ./terraform.sh prod destroy   # destroy infra in prod
# -------------------------

WORKSPACE="${1:-dev}"      # Default workspace = dev
ACTION="${2:-apply}"       # Default action = apply
LOGFILE="terraform_$(date +%F_%H-%M-%S).log"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  echo -e "${CYAN}$1${NC}"
  echo "$(date +%F_%T) $1" >> "$LOGFILE"
}

select_workspace() {
  if terraform workspace list | grep -q "$WORKSPACE"; then
    terraform workspace select "$WORKSPACE"
  else
    terraform workspace new "$WORKSPACE"
  fi
  log "🌍 Using workspace: $WORKSPACE"
}

run_terraform() {
  log "🚀 Initializing Terraform..."
  terraform init -input=false | tee -a "$LOGFILE"

  log "🧹 Formatting Terraform files..."
  terraform fmt -recursive | tee -a "$LOGFILE"

  log "✅ Validating Terraform code..."
  terraform validate | tee -a "$LOGFILE"

  if [ "$ACTION" == "apply" ]; then
    log "📜 Creating Terraform plan..."
    terraform plan -out=tfplan -input=false | tee -a "$LOGFILE"

    log "⚡ Applying Terraform changes..."
    terraform apply -input=false -auto-approve tfplan | tee -a "$LOGFILE"

    rm -f tfplan
    log "🎉 Apply completed successfully in $WORKSPACE!"

  elif [ "$ACTION" == "destroy" ]; then
    log "🔥 Destroying infrastructure in $WORKSPACE..."
    terraform destroy -auto-approve | tee -a "$LOGFILE"
    log "✅ Destroy completed in $WORKSPACE!"
  else
    log "❌ Unknown action: $ACTION (use apply/destroy)"
    exit 1
  fi
}

# ---- Main Flow ----
log "🚧 Starting Terraform automation..."
select_workspace
run_terraform

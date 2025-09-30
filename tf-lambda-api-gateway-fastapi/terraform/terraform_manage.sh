#!/usr/bin/env bash
# Advanced Terraform Automation Script (HTTP API + Lambda)
# Author: Shantanu (adapted for Lambda ZIP + API Gateway HTTP API)

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

# -------------------------
# Usage
#   ./terraform_manage.sh [workspace] [action]
# Examples:
#   ./terraform_manage.sh               # defaults: dev apply
#   ./terraform_manage.sh dev apply
#   ./terraform_manage.sh prod destroy
# Notes:
# - Looks for env/<workspace>.tfvars and passes it if found
# - Verifies the Lambda ZIP path before plan/apply
# -------------------------

WORKSPACE="${1:-dev}"          # default workspace = dev
ACTION="${2:-apply}"           # default action   = apply
LOGFILE="terraform_${WORKSPACE}_$(date +%F_%H-%M-%S).log"

# Colors
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${CYAN}$1${NC}"; echo "$(date +%F_%T) $1" >> "$LOGFILE"; }

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/env"
ENV_VARS_FILE="${ENV_DIR}/${WORKSPACE}.tfvars"

# Optional: pre-build ZIP (disabled by default)
pre_build() {
  if [[ -n "${PRE_BUILD:-}" ]]; then
    log "🔧 Running pre-build hook: ${PRE_BUILD}"
    bash -lc "${PRE_BUILD}"
  fi
}

select_workspace() {
  if terraform workspace list | grep -qE "^\*?\\s*${WORKSPACE}\$"; then
    terraform workspace select "${WORKSPACE}" >/dev/null
  else
    terraform workspace new "${WORKSPACE}" >/dev/null
  fi
  log "🌍 Using workspace: ${WORKSPACE}"
}

detect_vars_flag() {
  if [[ -f "${ENV_VARS_FILE}" ]]; then
    log "🗂️  Using vars file: ${ENV_VARS_FILE}"
    echo "-var-file=${ENV_VARS_FILE}"
  else
    echo ""
  fi
}

check_zip_exists() {
  # Determine zip_path from:
  # 1) TF_VAR_zip_path env var (highest priority)
  # 2) env/<workspace>.tfvars (zip_path = ...)
  # 3) terraform.tfvars (zip_path = ...)
  # Fallback: ./function.zip relative to repo root (informational)

  local zip_path="${TF_VAR_zip_path:-}"

  if [[ -z "${zip_path}" ]]; then
    # Try to read from tfvars files (best-effort; sed handles quotes/spaces)
    for f in "${ENV_VARS_FILE}" "${SCRIPT_DIR}/terraform.tfvars"; do
      if [[ -f "$f" ]]; then
        local found
        found="$(sed -nE 's/^[[:space:]]*zip_path[[:space:]]*=[[:space:]]*"?([^"]+)"?.*$/\1/p' "$f" | tail -n1 || true)"
        if [[ -n "$found" ]]; then zip_path="$found"; break; fi
      fi
    done
  fi

  if [[ -z "${zip_path}" ]]; then
    zip_path="./function.zip"
    log "⚠️  zip_path not set; assuming ${zip_path}"
  fi

  # Normalize relative path against script dir for existence check
  local abs_zip
  if [[ "$zip_path" = /* ]]; then abs_zip="$zip_path"; else abs_zip="${SCRIPT_DIR%/}/$zip_path"; fi

  if [[ ! -f "$abs_zip" ]]; then
    echo -e "${RED}❌ ZIP not found:${NC} ${abs_zip}"
    echo "   Set it via TF_VAR_zip_path or env/${WORKSPACE}.tfvars (zip_path = \"/path/to/function.zip\")."
    exit 1
  fi

  log "📦 Using Lambda ZIP: $abs_zip"
}

run_terraform() {
  local VARS_FLAG; VARS_FLAG="$(detect_vars_flag)"

  log "🚀 Initializing Terraform..."
  terraform init -input=false | tee -a "$LOGFILE"

  log "🧹 Formatting Terraform files..."
  terraform fmt -recursive | tee -a "$LOGFILE"

  log "✅ Validating Terraform code..."
  terraform validate | tee -a "$LOGFILE"

  if [[ "$ACTION" == "apply" ]]; then
    log "📜 Creating Terraform plan..."
    terraform plan -out=tfplan -input=false ${VARS_FLAG} | tee -a "$LOGFILE"

    log "⚡ Applying Terraform changes..."
    terraform apply -input=false -auto-approve tfplan | tee -a "$LOGFILE"
    rm -f tfplan

    # Show key outputs if present
    echo
    if terraform output -raw invoke_url >/dev/null 2>&1; then
      local URL; URL="$(terraform output -raw invoke_url)"
      echo -e "${GREEN}✅ Invoke URL:${NC} ${URL}"
      echo -e "${GREEN}Try:${NC} curl -i \"${URL}\""
      echo -e "${GREEN}     ${NC} curl -i \"${URL}api/v1/users\""
    elif terraform output -raw invoke_url_rest >/dev null 2>&1; then
      local URL; URL="$(terraform output -raw invoke_url_rest)"
      echo -e "${GREEN}✅ Invoke URL (REST):${NC} ${URL}"
      echo -e "${GREEN}Try:${NC} curl -i \"${URL}/\""
      echo -e "${GREEN}     ${NC} curl -i \"${URL}/api/v1/users\""
    fi

    log "🎉 Apply completed successfully in ${WORKSPACE}!"

  elif [[ "$ACTION" == "destroy" ]]; then
    log "🔥 Destroying infrastructure in ${WORKSPACE}..."
    terraform destroy -auto-approve ${VARS_FLAG} | tee -a "$LOGFILE"
    log "✅ Destroy completed in ${WORKSPACE}!"
  else
    log "❌ Unknown action: ${ACTION} (use apply|destroy)"
    exit 1
  fi
}

# ---- Main Flow ----
log "🚧 Starting Terraform automation..."
cd "$SCRIPT_DIR"
pre_build
select_workspace
check_zip_exists
run_terraform

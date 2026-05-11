#!/usr/bin/env bash
# 00_variables.sh — edit values then `source` this file (don't execute).
# Other scripts will source it automatically.

# ── Edit these ──────────────────────────────────────
export BASE_NAME="pec"
export ENV_NAME="dev"
export LOCATION="eastus2"
export OPENAI_LOCATION="eastus2"      # not all regions have gpt-4o

# ── Derived ─────────────────────────────────────────
export SUFFIX="$(echo -n "${BASE_NAME}${ENV_NAME}$(whoami)" | md5sum | cut -c1-6)"
export RG="rg-${BASE_NAME}-${ENV_NAME}"
export STORAGE="st${BASE_NAME}${ENV_NAME}${SUFFIX}"
export KV="kv-${BASE_NAME}-${ENV_NAME}-${SUFFIX}"
export SQL_SERVER_NAME="sql-${BASE_NAME}-${ENV_NAME}-${SUFFIX}"
export SQL_DB="pecdb"
export SQL_ADMIN_USER="pecadmin"
# SQL_ADMIN_PASSWORD must be set in your shell or .env BEFORE running scripts:
#   export SQL_ADMIN_PASSWORD='YourStrong!Pass1'
export OPENAI="aoai-${BASE_NAME}-${ENV_NAME}-${SUFFIX}"
export ACR="acr${BASE_NAME}${ENV_NAME}${SUFFIX}"
export PLAN="plan-${BASE_NAME}-${ENV_NAME}"
export API_APP="app-${BASE_NAME}-${ENV_NAME}-${SUFFIX}-api"
export SWA="swa-${BASE_NAME}-${ENV_NAME}-${SUFFIX}"
export LAW="law-${BASE_NAME}-${ENV_NAME}"
export APPINSIGHTS="ai-${BASE_NAME}-${ENV_NAME}"

echo "Variables loaded:"
echo "  RG=$RG"
echo "  SUFFIX=$SUFFIX"
echo "  SQL_SERVER_NAME=$SQL_SERVER_NAME"
echo "  API_APP=$API_APP"
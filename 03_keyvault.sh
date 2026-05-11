#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating Key Vault $KV"
az keyvault create \
  --name "$KV" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --enable-rbac-authorization true \
  --enable-soft-delete true \
  --output table

# Grant yourself secret-officer access
ME=$(az ad signed-in-user show --query id -o tsv)
KV_ID=$(az keyvault show -n "$KV" -g "$RG" --query id -o tsv)

echo ">> Granting current user Key Vault Secrets Officer"
az role assignment create \
  --assignee "$ME" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID" \
  --output none || echo "(role assignment may already exist)"

# Store SQL admin password and AI reader password
if [[ -n "${SQL_ADMIN_PASSWORD:-}" ]]; then
  az keyvault secret set --vault-name "$KV" \
    --name "sql-admin-password" --value "$SQL_ADMIN_PASSWORD" --output none
  echo "Stored sql-admin-password in $KV"
fi

if [[ -n "${AI_READER_PASSWORD:-}" ]]; then
  az keyvault secret set --vault-name "$KV" \
    --name "ai-reader-password" --value "$AI_READER_PASSWORD" --output none
  echo "Stored ai-reader-password in $KV"
fi

echo "Done. Key Vault: $KV"
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating Azure Container Registry $ACR"
az acr create \
  --name "$ACR" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Basic \
  --admin-enabled true \
  --output table

ACR_PASSWORD=$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)
az keyvault secret set --vault-name "$KV" --name "acr-password" --value "$ACR_PASSWORD" --output none

echo "Done. ACR login server: ${ACR}.azurecr.io"

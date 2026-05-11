#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating App Service Plan $PLAN (Linux P1v3)"
az appservice plan create \
  --name "$PLAN" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --is-linux \
  --sku P1V3 \
  --output table

ACR_SERVER="${ACR}.azurecr.io"
IMAGE="${ACR_SERVER}/pec-api:latest"

echo ">> Creating Web App $API_APP"
az webapp create \
  --name "$API_APP" \
  --resource-group "$RG" \
  --plan "$PLAN" \
  --deployment-container-image-name "$IMAGE" \
  --output table

echo ">> Enabling system-assigned managed identity"
az webapp identity assign \
  --name "$API_APP" \
  --resource-group "$RG" \
  --output table

echo ">> Configuring ACR pull credentials"
ACR_PASSWORD=$(az keyvault secret show --vault-name "$KV" --name "acr-password" --query "value" -o tsv)
az webapp config container set \
  --name "$API_APP" \
  --resource-group "$RG" \
  --docker-custom-image-name "$IMAGE" \
  --docker-registry-server-url "https://${ACR_SERVER}" \
  --docker-registry-server-user "$ACR" \
  --docker-registry-server-password "$ACR_PASSWORD" \
  --output none

echo ">> Setting app settings"
AOAI_ENDPOINT=$(az keyvault secret show --vault-name "$KV" --name "aoai-endpoint" --query "value" -o tsv)
CONN=$(az keyvault secret show --vault-name "$KV" --name "sql-connection-string" --query "value" -o tsv)

az webapp config appsettings set \
  --name "$API_APP" \
  --resource-group "$RG" \
  --settings \
    AZURE_OPENAI_ENDPOINT="$AOAI_ENDPOINT" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4o" \
    SQL_CONNECTION_STRING="$CONN" \
    KEY_VAULT_NAME="$KV" \
    WEBSITES_PORT=8000 \
  --output none

echo "Done. API URL: https://${API_APP}.azurewebsites.net"

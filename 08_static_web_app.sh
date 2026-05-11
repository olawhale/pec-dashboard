#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating Static Web App $SWA"
az staticwebapp create \
  --name "$SWA" \
  --resource-group "$RG" \
  --location "eastus2" \
  --sku Free \
  --output table

SWA_URL=$(az staticwebapp show -n "$SWA" -g "$RG" --query "defaultHostname" -o tsv)
API_URL="https://${API_APP}.azurewebsites.net"

echo ">> Setting Static Web App environment variable for API URL"
az staticwebapp appsettings set \
  --name "$SWA" \
  --setting-names "VITE_API_BASE_URL=$API_URL" \
  --output none

echo "Done. SWA URL: https://${SWA_URL}"
echo "      Remember to configure CORS on the API App Service to allow this origin."

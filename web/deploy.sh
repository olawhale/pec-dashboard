#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../00_variables.sh"

API_URL="https://${API_APP}.azurewebsites.net"

echo ">> Building frontend (VITE_API_BASE_URL=$API_URL)"
VITE_API_BASE_URL="$API_URL" npm run build

echo ">> Deploying to Static Web App $SWA"
SWA_TOKEN=$(az staticwebapp secrets list -n "$SWA" -g "$RG" --query "properties.apiKey" -o tsv)
npx @azure/static-web-apps-cli deploy dist \
  --deployment-token "$SWA_TOKEN" \
  --env production

echo "Done. Frontend live at: https://$(az staticwebapp show -n $SWA -g $RG --query defaultHostname -o tsv)"

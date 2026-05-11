#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../00_variables.sh"

IMAGE="${ACR}.azurecr.io/pec-api:latest"

echo ">> Building and pushing API image to $ACR"
az acr build \
  --registry "$ACR" \
  --image "pec-api:latest" \
  "$(dirname "$0")" \
  --file "$(dirname "$0")/Dockerfile"

echo ">> Restarting App Service $API_APP to pull new image"
az webapp restart --name "$API_APP" --resource-group "$RG"

echo "Done. API live at: https://${API_APP}.azurewebsites.net"

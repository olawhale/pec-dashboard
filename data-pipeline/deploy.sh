#!/usr/bin/env bash
# Build and push the data-pipeline container image, then schedule it as a
# daily Azure Container Instance (one-shot) via a Logic App trigger (or
# swap for Azure Container Apps Jobs).
set -euo pipefail
source "$(dirname "$0")/../00_variables.sh"

IMAGE="${ACR}.azurecr.io/pec-pipeline:latest"

echo ">> Building data-pipeline image"
az acr build \
  --registry "$ACR" \
  --image "pec-pipeline:latest" \
  "$(dirname "$0")" \
  --file "$(dirname "$0")/Dockerfile"

echo ">> Image pushed: $IMAGE"
echo ""
echo "To run a one-off ingest:"
echo "  az container create \\"
echo "    --resource-group $RG \\"
echo "    --name pec-ingest-job \\"
echo "    --image $IMAGE \\"
echo "    --registry-login-server ${ACR}.azurecr.io \\"
echo "    --registry-username $ACR \\"
echo "    --registry-password \$(az keyvault secret show --vault-name $KV --name acr-password --query value -o tsv) \\"
echo "    --assign-identity \\"
echo "    --environment-variables \\"
echo "      KEY_VAULT_NAME=$KV \\"
echo "      STORAGE_ACCOUNT_NAME=$STORAGE \\"
echo "      BILLING_ACCOUNT_ID=<YOUR_BILLING_ACCOUNT_ID> \\"
echo "    --restart-policy Never \\"
echo "    --output table"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating storage account $STORAGE (ADLS Gen2)"
az storage account create \
  --name "$STORAGE" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --hns true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output table

KEY=$(az storage account keys list -g "$RG" -n "$STORAGE" --query "[0].value" -o tsv)

for c in bronze silver gold; do
  echo ">> Creating container $c"
  az storage container create \
    --name "$c" \
    --account-name "$STORAGE" \
    --account-key "$KEY" \
    --output none
done

echo "Done. Storage account: $STORAGE"
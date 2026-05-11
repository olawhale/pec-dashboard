#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating Azure OpenAI account $OPENAI in $OPENAI_LOCATION"
az cognitiveservices account create \
  --name "$OPENAI" \
  --resource-group "$RG" \
  --location "$OPENAI_LOCATION" \
  --kind OpenAI \
  --sku S0 \
  --output table

echo ">> Deploying gpt-4o model"
az cognitiveservices account deployment create \
  --resource-group "$RG" \
  --name "$OPENAI" \
  --deployment-name "gpt-4o" \
  --model-name "gpt-4o" \
  --model-version "2024-08-06" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name Standard \
  --output table

ENDPOINT=$(az cognitiveservices account show -g "$RG" -n "$OPENAI" \
  --query "properties.endpoint" -o tsv)
KEY=$(az cognitiveservices account keys list -g "$RG" -n "$OPENAI" \
  --query "key1" -o tsv)

az keyvault secret set --vault-name "$KV" --name "aoai-endpoint" --value "$ENDPOINT" --output none
az keyvault secret set --vault-name "$KV" --name "aoai-key"      --value "$KEY"      --output none

echo "Done. AOAI endpoint: $ENDPOINT"

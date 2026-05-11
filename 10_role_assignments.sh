#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Looking up API app managed identity principal ID"
PRINCIPAL_ID=$(az webapp identity show \
  --name "$API_APP" --resource-group "$RG" \
  --query "principalId" -o tsv)

STORAGE_ID=$(az storage account show -g "$RG" -n "$STORAGE" --query "id" -o tsv)
KV_ID=$(az keyvault show -n "$KV" -g "$RG" --query "id" -o tsv)
OPENAI_ID=$(az cognitiveservices account show -g "$RG" -n "$OPENAI" --query "id" -o tsv)
AI_ID=$(az monitor app-insights component show -a "$APPINSIGHTS" -g "$RG" --query "id" -o tsv)

assign() {
  az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "$1" \
    --scope "$2" \
    --output none \
    && echo "  Assigned: $1" \
    || echo "  (already exists or skipped): $1"
}

echo ">> Assigning roles to API app managed identity"
assign "Storage Blob Data Reader"              "$STORAGE_ID"
assign "Key Vault Secrets User"                "$KV_ID"
assign "Cognitive Services OpenAI User"        "$OPENAI_ID"
assign "Monitoring Metrics Publisher"          "$AI_ID"

echo ""
echo ">> NOTE: Grant the managed identity access to the SQL database by running:"
echo "   In Azure SQL, execute:"
echo "   CREATE USER [${API_APP}] FROM EXTERNAL PROVIDER;"
echo "   ALTER ROLE db_datareader ADD MEMBER [${API_APP}];"
echo ""
echo "Done. Role assignments complete."

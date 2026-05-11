#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating Log Analytics Workspace $LAW"
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "$LAW" \
  --location "$LOCATION" \
  --sku PerGB2018 \
  --output table

LAW_ID=$(az monitor log-analytics workspace show \
  -g "$RG" -n "$LAW" --query "id" -o tsv)

echo ">> Creating Application Insights $APPINSIGHTS"
az monitor app-insights component create \
  --app "$APPINSIGHTS" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --workspace "$LAW_ID" \
  --kind web \
  --application-type web \
  --output table

CONN_STR=$(az monitor app-insights component show \
  -a "$APPINSIGHTS" -g "$RG" \
  --query "connectionString" -o tsv)

az keyvault secret set \
  --vault-name "$KV" \
  --name "appinsights-connection-string" \
  --value "$CONN_STR" \
  --output none

echo ">> Adding APPLICATIONINSIGHTS_CONNECTION_STRING to API app"
az webapp config appsettings set \
  --name "$API_APP" \
  --resource-group "$RG" \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$CONN_STR" \
  --output none

echo "Done. App Insights: $APPINSIGHTS"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

: "${SQL_ADMIN_PASSWORD:?SQL_ADMIN_PASSWORD must be exported before running this script}"

echo ">> Creating Azure SQL Server $SQL_SERVER_NAME"
az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD" \
  --output table

echo ">> Allowing Azure services through firewall"
az sql server firewall-rule create \
  --resource-group "$RG" \
  --server "$SQL_SERVER_NAME" \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  --output none

echo ">> Creating database $SQL_DB"
az sql db create \
  --resource-group "$RG" \
  --server "$SQL_SERVER_NAME" \
  --name "$SQL_DB" \
  --service-objective S2 \
  --zone-redundant false \
  --output table

CONN="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Database=${SQL_DB};User Id=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};Encrypt=yes;TrustServerCertificate=no"
az keyvault secret set \
  --vault-name "$KV" \
  --name "sql-connection-string" \
  --value "$CONN" \
  --output none

echo "Done. SQL Server: ${SQL_SERVER_NAME}.database.windows.net  DB: $SQL_DB"

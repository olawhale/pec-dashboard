#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../00_variables.sh"

: "${SQL_ADMIN_PASSWORD:?SQL_ADMIN_PASSWORD must be set}"

SERVER="${SQL_SERVER_NAME}.database.windows.net"
echo ">> Running schema migrations on $SERVER / $SQL_DB"

for f in "$(dirname "$0")"/0*.sql; do
  echo "   Executing $f"
  sqlcmd \
    -S "$SERVER" \
    -d "$SQL_DB" \
    -U "$SQL_ADMIN_USER" \
    -P "$SQL_ADMIN_PASSWORD" \
    -i "$f" \
    -I \
    -l 60
done

echo "Done. Schema applied."

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_variables.sh"

echo ">> Creating resource group $RG in $LOCATION"
az group create --name "$RG" --location "$LOCATION" --output table
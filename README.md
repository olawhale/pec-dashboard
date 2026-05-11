# PEC Dashboard

Partner Earned Credit dashboard with forecasting and an AI query agent, built on Azure.

## Architecture

- **Data**: Cost Management API → ADLS Gen2 → Azure SQL star schema
- **Forecast**: Prophet model trained nightly, written to `FactPECForecast`
- **API**: FastAPI on Azure App Service (Linux container)
- **Frontend**: React + Vite + TypeScript on Azure Static Web Apps
- **AI agent**: Azure OpenAI (gpt-4o) generates SQL against a locked-down view

## First-time setup

```bash
# 1. Sign in to Azure
az login
az account set --subscription "<your-sub-id>"

# 2. Provision everything (run in order)
cd scripts
bash 00_variables.sh    # edit this file first to set your names
bash 01_resource_group.sh
bash 02_storage.sh
bash 03_keyvault.sh
bash 04_sql.sh
bash 05_openai.sh
bash 06_acr.sh
bash 07_appservice.sh
bash 08_static_web_app.sh
bash 09_appinsights.sh
bash 10_role_assignments.sh

# 3. Deploy schema
cd ../sql
bash run_schema.sh

# 4. Build and deploy the API
cd ../api
bash deploy.sh

# 5. Deploy the data pipeline
cd ../data-pipeline
bash deploy.sh

# 6. Build and deploy the frontend
cd ../web
npm install
npm run build
bash deploy.sh
```

## Local development

See `api/README.md` and `web/README.md` for running each piece locally.

## Project layout

```
pec-dashboard/
├── scripts/          # numbered Azure CLI provisioning scripts
├── data-pipeline/    # daily PEC ingestion + Prophet forecast
├── sql/              # T-SQL schema, views, RLS
├── api/              # FastAPI backend with NL-to-SQL agent
├── web/              # React + Vite frontend
└── .github/workflows # CI/CD
```
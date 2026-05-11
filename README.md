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

# 2. Set required secrets (copy .env.example → .env and edit, then source it)
cp .env.example .env
# Edit .env, then:
export SQL_ADMIN_PASSWORD='YourStrong!Pass1'
export AI_READER_PASSWORD='AnotherStrong!Pass2'
export BILLING_ACCOUNT_ID='<your-billing-account-id>'

# 3. Provision everything (scripts are at repo root, run in order)
bash 00_variables.sh    # edit BASE_NAME / LOCATION first
bash 01_resource_groups.sh
bash 02_storage.sh
bash 03_keyvault.sh
bash 04_sql.sh
bash 05_openai.sh
bash 06_acr.sh
bash 07_appservice.sh
bash 08_static_web_app.sh
bash 09_appinsights.sh
bash 10_role_assignments.sh

# 4. Deploy schema
cd sql && bash run_schema.sh && cd ..

# 5. Build and deploy the API
cd api && bash deploy.sh && cd ..

# 6. Deploy the data pipeline image
cd data-pipeline && bash deploy.sh && cd ..

# 7. Build and deploy the frontend
cd web && npm install && bash deploy.sh && cd ..
```

## GitHub Actions CI/CD

Add these secrets to your GitHub repository (`Settings → Secrets`):

| Secret | Description |
|--------|-------------|
| `AZURE_CREDENTIALS` | `az ad sp create-for-rbac --sdk-auth` output |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | From `az staticwebapp secrets list` |
| `VITE_API_BASE_URL` | `https://<api-app>.azurewebsites.net` |

Push to `main` to trigger automatic deployments.

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
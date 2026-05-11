# PEC Dashboard API

FastAPI backend deployed as a Linux container on Azure App Service.

## Local development

```bash
pip install -r requirements.txt

# Set env vars (copy from .env.example at repo root)
export SQL_CONNECTION_STRING="..."
export AZURE_OPENAI_ENDPOINT="https://..."
export AZURE_OPENAI_DEPLOYMENT="gpt-4o"

uvicorn main:app --reload
```

Open http://localhost:8000/docs for the interactive API explorer.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Liveness probe |
| GET | /api/pec/summary | Monthly PEC by partner/service |
| GET | /api/pec/forecast | Forecast vs. actuals |
| GET | /api/pec/partners | List all partners |
| POST | /api/query | Natural-language → SQL query |

## Deploy

```bash
bash deploy.sh
```

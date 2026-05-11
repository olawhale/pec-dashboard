# PEC Dashboard – Web

React + Vite + TypeScript frontend deployed to Azure Static Web Apps.

## Local development

```bash
npm install
VITE_API_BASE_URL=http://localhost:8000 npm run dev
```

Open http://localhost:5173

## Deploy

```bash
bash deploy.sh
```

## Pages

| Route | Description |
|-------|-------------|
| `/` | Dashboard — KPI cards, PEC trend chart, forecast overlay |
| `/query` | AI Query — natural-language interface to the PEC dataset |

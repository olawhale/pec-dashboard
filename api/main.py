from __future__ import annotations

import os
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import pec, query

logging.basicConfig(level=logging.INFO)

app = FastAPI(title="PEC Dashboard API", version="1.0.0")

ALLOWED_ORIGINS = os.environ.get(
    "CORS_ORIGINS",
    "http://localhost:5173",
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(pec.router)
app.include_router(query.router)


@app.get("/health")
def health():
    return {"status": "ok"}

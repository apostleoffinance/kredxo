from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.credit import router as credit_router
from app.api.demo import router as demo_router
from app.api.health import router as health_router
from app.api.markets import router as markets_router
from app.api.policy import router as policy_router
from app.api.positions import router as positions_router
from app.api.risk import router as risk_router
from app.api.stress import router as stress_router
from app.api.trades import router as trades_router
from app.db import init_db, ping_database


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if ping_database():
        init_db()
    yield


app = FastAPI(
    title="Kredxo",
    description="Credit and risk intelligence. Python decides; Solidity enforces.",
    version="0.19.0",
    lifespan=lifespan,
)

CORS_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://[::1]:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(demo_router)
app.include_router(trades_router)
app.include_router(credit_router)
app.include_router(risk_router)
app.include_router(policy_router)
app.include_router(markets_router)
app.include_router(positions_router)
app.include_router(stress_router)

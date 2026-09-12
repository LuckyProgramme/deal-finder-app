"""FastAPI application entry point for Deal Finder."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .crud import seed_default_targets_if_empty
from .database import Base, SessionLocal, engine
from .routes.deals import router as deals_router
from .routes.scraper import router as scraper_router
from .routes.targets import router as targets_router
from .scraper_runner import scraper_manager


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan event handler initializing DB tables, seeding data, and logger hooks."""
    # 1. Ensure all database tables exist
    Base.metadata.create_all(bind=engine)

    # 2. Seed default targets if table is empty
    db = SessionLocal()
    try:
        seed_default_targets_if_empty(db)
    finally:
        db.close()

    # 3. Hook SSE log handler
    scraper_manager.register_logging()

    yield

    # Cleanup if needed
    scraper_manager.stop_scrape()


app = FastAPI(
    title="Deal Finder API",
    description="REST backend service and real-time SSE log streaming for Carousell Deal Finder",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware for Flutter desktop and web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include route handlers
app.include_router(targets_router)
app.include_router(deals_router)
app.include_router(scraper_router)


@app.get("/api/health", tags=["System"])
def health_check() -> dict[str, str]:
    """Basic health probe endpoint."""
    return {"status": "ok", "service": "deal-finder-api"}

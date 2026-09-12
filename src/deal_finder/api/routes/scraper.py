"""API endpoints for controlling the live scraper and streaming real-time SSE logs."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from ..schemas import ScraperStartRequest, ScraperStatusResponse
from ..scraper_runner import scraper_manager

router = APIRouter(prefix="/api/scraper", tags=["Live Scraper Runner"])


@router.get("/status", response_model=ScraperStatusResponse)
def get_scraper_status() -> ScraperStatusResponse:
    """Get the current execution status and progress of the scraper."""
    return ScraperStatusResponse(
        is_running=scraper_manager.is_running,
        current_target=scraper_manager.current_target,
        progress=scraper_manager.progress,
        status_message=scraper_manager.status_message,
        last_run_id=scraper_manager.last_run_id,
    )


@router.post("/start", response_model=ScraperStatusResponse)
def start_scraper(request: ScraperStartRequest | None = None) -> ScraperStatusResponse:
    """Trigger the live scraper process in the background."""
    target_ids = request.target_ids if request else None
    started = scraper_manager.start_scrape(target_ids=target_ids)
    if not started:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Scraper is already running.",
        )
    return get_scraper_status()


@router.post("/stop", response_model=ScraperStatusResponse)
def stop_scraper() -> ScraperStatusResponse:
    """Request graceful cancellation of the active scraper process."""
    stopped = scraper_manager.stop_scrape()
    if not stopped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Scraper is not currently running.",
        )
    return get_scraper_status()


@router.get("/stream")
async def stream_scraper_logs() -> StreamingResponse:
    """Server-Sent Events (SSE) endpoint streaming live log messages, progress, and status."""
    return StreamingResponse(
        scraper_manager.subscribe(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )

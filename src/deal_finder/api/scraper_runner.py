"""Asynchronous scraper task runner with Server-Sent Events (SSE) log broadcasting."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import json
import logging
from typing import Any, AsyncGenerator

from sqlalchemy.orm import Session

from .database import SessionLocal
from .db_models import ScraperRunModel, TargetModel
from .crud import upsert_deal
from ..deal_engine import run_two_stage_cascade
from ..models import PriceListTarget
from ..scraper import scrape_price_list_sources


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class SSELogHandler(logging.Handler):
    """Custom logging handler that routes log records into the ScraperManager broadcast queue."""

    def __init__(self, manager: ScraperManager) -> None:
        super().__init__()
        self.manager = manager

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            payload = {
                "level": record.levelname,
                "time": datetime.fromtimestamp(record.created, tz=timezone.utc).strftime("%H:%M:%S"),
                "message": msg,
            }
            self.manager.broadcast_sync("log", payload)
        except Exception:
            self.handleError(record)


class ScraperManager:
    """Singleton manager controlling scraper lifecycle, status, and SSE clients."""

    def __init__(self) -> None:
        self.is_running: bool = False
        self.current_target: str | None = None
        self.progress: float = 0.0
        self.status_message: str = "Idle"
        self.last_run_id: int | None = None
        self._subscribers: set[asyncio.Queue[str]] = set()
        self._cancel_requested: bool = False
        self._log_handler: SSELogHandler | None = None
        self._task: asyncio.Task | None = None
        self._loop: asyncio.AbstractEventLoop | None = None

    def register_logging(self) -> None:
        if self._log_handler is None:
            self._log_handler = SSELogHandler(self)
            formatter = logging.Formatter("%(message)s")
            self._log_handler.setFormatter(formatter)
            logging.getLogger().addHandler(self._log_handler)

    def broadcast_sync(self, event_type: str, data: Any) -> None:
        """Called from sync logging handler or background threads."""
        if not self._subscribers or self._loop is None:
            return

        frame = f"event: {event_type}\ndata: {json.dumps(data)}\n\n"
        for q in list(self._subscribers):
            self._loop.call_soon_threadsafe(q.put_nowait, frame)

    async def broadcast_async(self, event_type: str, data: Any) -> None:
        """Broadcast an event frame to all connected SSE clients."""
        frame = f"event: {event_type}\ndata: {json.dumps(data)}\n\n"
        for q in list(self._subscribers):
            await q.put(frame)

    async def subscribe(self) -> AsyncGenerator[str, None]:
        """Subscribe an SSE client to receive real-time events."""
        q: asyncio.Queue[str] = asyncio.Queue()
        self._subscribers.add(q)
        try:
            # Yield initial status frame
            initial_status = {
                "is_running": self.is_running,
                "current_target": self.current_target,
                "progress": self.progress,
                "status_message": self.status_message,
                "last_run_id": self.last_run_id,
            }
            yield f"event: status\ndata: {json.dumps(initial_status)}\n\n"
            while True:
                data = await q.get()
                yield data
        finally:
            self._subscribers.discard(q)

    def start_scrape(self, target_ids: list[int] | None = None) -> bool:
        """Start the scraper task in the background if not already running."""
        if self.is_running:
            return False

        self._loop = asyncio.get_running_loop()
        self.register_logging()
        self.is_running = True
        self._cancel_requested = False
        self.progress = 0.0
        self.status_message = "Initializing scraper..."
        self._task = asyncio.create_task(self._run_scrape_pipeline(target_ids))
        return True

    def stop_scrape(self) -> bool:
        """Request cancellation of the running scraper."""
        if not self.is_running:
            return False
        self._cancel_requested = True
        self.status_message = "Cancellation requested..."
        return True

    async def _run_scrape_pipeline(self, target_ids: list[int] | None = None) -> None:
        run_record_id: int | None = None
        db: Session = SessionLocal()
        try:
            # Create scraper run tracking record
            run = ScraperRunModel(started_at=_utc_now(), status="running")
            db.add(run)
            db.commit()
            db.refresh(run)
            run_record_id = run.id
            self.last_run_id = run_record_id

            # 1. Fetch targets from SQLite
            query = db.query(TargetModel)
            if target_ids:
                query = query.filter(TargetModel.id.in_(target_ids))
            db_targets = query.all()

            if not db_targets:
                self.status_message = "No targets configured to scrape."
                await self.broadcast_async("status", {"status_message": self.status_message, "progress": 1.0})
                return

            domain_targets: list[PriceListTarget] = []
            for t in db_targets:
                domain_targets.append(
                    PriceListTarget(
                        item_name=t.item_name,
                        category=t.category,
                        deal_price=t.deal_price,
                        retail_price=t.retail_price,
                        downsizing_keywords=t.parse_downsizing_keywords(),
                        freebie_keywords=t.parse_freebie_keywords(),
                        notes=t.notes,
                        target_type=t.target_type,
                        allow_bundle_check=t.allow_bundle_check,
                    )
                )

            total_targets = len(domain_targets)
            self.status_message = f"Found {total_targets} target(s). Beginning Carousell marketplace scrape..."
            await self.broadcast_async("status", {"status_message": self.status_message, "progress": 0.05})

            # Run blocking scraping in default thread executor to keep FastAPI responsive
            loop = asyncio.get_running_loop()

            def scrape_worker() -> Any:
                return scrape_price_list_sources(domain_targets)

            self.status_message = "Fetching marketplace listings..."
            await self.broadcast_async("status", {"status_message": self.status_message, "progress": 0.20})

            batch_result = await loop.run_in_executor(None, scrape_worker)

            if self._cancel_requested:
                self.status_message = "Scrape stopped by user."
                return

            total_listings = len(batch_result.listings)
            self.status_message = f"Scraped {total_listings} listing(s). Running matching & deal cascade..."
            await self.broadcast_async("status", {"status_message": self.status_message, "progress": 0.50})

            # Run cascade analysis
            def cascade_worker() -> Any:
                return run_two_stage_cascade(batch_result.listings, domain_targets)

            cascade_result = await loop.run_in_executor(None, cascade_worker)

            confirmed_deals = cascade_result.confirmed_deals
            self.status_message = f"Cascade complete. Discovered {len(confirmed_deals)} confirmed deal(s). Saving to database..."
            await self.broadcast_async("status", {"status_message": self.status_message, "progress": 0.85})

            # Save confirmed deals to SQLite
            for deal_data in confirmed_deals:
                # Calculate savings if retail_price is available, else deal_price - price
                price = deal_data.get("price")
                deal_price = deal_data.get("deal_price", 0.0)
                retail_price = deal_data.get("retail_price")
                benchmark = retail_price if retail_price is not None else deal_price
                savings = max(0.0, benchmark - price) if price is not None else None
                deal_data["savings"] = savings

                upsert_deal(db, deal_data)

            # Update run record
            run = db.get(ScraperRunModel, run_record_id)
            if run:
                run.finished_at = _utc_now()
                run.status = "completed"
                run.total_listings_scraped = total_listings
                run.total_deals_found = len(confirmed_deals)
                db.commit()

            self.status_message = f"Scrape completed successfully! {len(confirmed_deals)} deals found."
            self.progress = 1.0
            await self.broadcast_async("complete", {
                "status": "completed",
                "total_scraped": total_listings,
                "total_deals": len(confirmed_deals),
                "run_id": run_record_id,
            })

        except Exception as exc:
            logging.exception("Error during scrape execution: %s", exc)
            self.status_message = f"Scrape error: {exc}"
            if run_record_id:
                run = db.get(ScraperRunModel, run_record_id)
                if run:
                    run.finished_at = _utc_now()
                    run.status = "failed"
                    run.error_message = str(exc)
                    db.commit()
            await self.broadcast_async("error", {"error": str(exc)})
        finally:
            self.is_running = False
            self.current_target = None
            db.close()


# Global singleton instance
scraper_manager = ScraperManager()

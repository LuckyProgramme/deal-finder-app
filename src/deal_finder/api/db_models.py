"""SQLAlchemy ORM models for Price List targets, deals, and scraper runs."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, Sequence

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class TargetModel(Base):
    """SQLAlchemy model representing a target item row in the Price List."""

    __tablename__ = "targets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    item_name: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    deal_price: Mapped[float] = mapped_column(Float, nullable=False)
    retail_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    downsizing_keywords: Mapped[str] = mapped_column(String(500), default="")
    freebie_keywords: Mapped[str] = mapped_column(String(500), default="")
    notes: Mapped[str] = mapped_column(Text, default="")
    target_type: Mapped[str] = mapped_column(String(50), default="Hardware")
    allow_bundle_check: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now, onupdate=_utc_now)

    def parse_downsizing_keywords(self) -> tuple[str, ...]:
        return tuple(p.strip().lower() for p in self.downsizing_keywords.split(",") if p.strip())

    def parse_freebie_keywords(self) -> tuple[str, ...]:
        return tuple(p.strip().lower() for p in self.freebie_keywords.split(",") if p.strip())


class DealModel(Base):
    """SQLAlchemy model representing a discovered Carousell deal."""

    __tablename__ = "deals"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
    deal_price: Mapped[float] = mapped_column(Float, nullable=False)
    retail_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    savings: Mapped[float | None] = mapped_column(Float, nullable=True)
    matched_item: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    condition: Mapped[str] = mapped_column(String(100), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    link: Mapped[str] = mapped_column(String(1000), default="")
    seller: Mapped[str] = mapped_column(String(100), default="")
    category: Mapped[str] = mapped_column(String(100), default="")
    thumbnail_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    issues_json: Mapped[str] = mapped_column(Text, default="[]")
    freebies_json: Mapped[str] = mapped_column(Text, default="[]")
    confidence: Mapped[int] = mapped_column(Integer, default=0)
    audit_source: Mapped[str] = mapped_column(String(50), default="local_fallback")
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_dismissed: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    first_seen_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now, onupdate=_utc_now)

    @property
    def issues(self) -> list[str]:
        try:
            return json.loads(self.issues_json or "[]")
        except Exception:
            return []

    @issues.setter
    def issues(self, val: Sequence[str]) -> None:
        self.issues_json = json.dumps(list(val))

    @property
    def freebies(self) -> list[str]:
        try:
            return json.loads(self.freebies_json or "[]")
        except Exception:
            return []

    @freebies.setter
    def freebies(self, val: Sequence[str]) -> None:
        self.freebies_json = json.dumps(list(val))


class ScraperRunModel(Base):
    """SQLAlchemy model tracking execution sessions of the scraper."""

    __tablename__ = "scraper_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="running")
    total_listings_scraped: Mapped[int] = mapped_column(Integer, default=0)
    total_deals_found: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

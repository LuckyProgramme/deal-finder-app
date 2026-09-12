"""Pydantic schemas for request validation and API serialization."""

from __future__ import annotations

from datetime import datetime
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class TargetBase(BaseModel):
    item_name: str = Field(..., min_length=1, description="Item identifier or title")
    category: str = Field(..., min_length=1, description="Product category")
    deal_price: float = Field(..., gt=0, description="Target deal threshold price in PHP")
    retail_price: float | None = Field(default=None, description="Benchmark retail price in PHP")
    downsizing_keywords: str = Field(default="", description="Comma-separated keywords indicating downsized model")
    freebie_keywords: str = Field(default="", description="Comma-separated keywords indicating included bonus items")
    notes: str = Field(default="", description="Operator notes or special instructions")
    target_type: Literal["Hardware", "Game"] = Field(default="Hardware", description="Item classification")
    allow_bundle_check: bool = Field(default=False, description="Whether to analyze bundle breakdown")


class TargetCreate(TargetBase):
    pass


class TargetUpdate(BaseModel):
    item_name: str | None = None
    category: str | None = None
    deal_price: float | None = None
    retail_price: float | None = None
    downsizing_keywords: str | None = None
    freebie_keywords: str | None = None
    notes: str | None = None
    target_type: Literal["Hardware", "Game"] | None = None
    allow_bundle_check: bool | None = None


class TargetResponse(TargetBase):
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DealResponse(BaseModel):
    id: str
    title: str
    price: float | None
    deal_price: float
    retail_price: float | None
    savings: float | None
    matched_item: str
    condition: str
    description: str
    link: str
    seller: str
    category: str
    thumbnail_url: str | None
    issues: list[str] = Field(default_factory=list)
    freebies: list[str] = Field(default_factory=list)
    confidence: int
    audit_source: str
    is_favorite: bool
    is_dismissed: bool
    first_seen_at: datetime
    last_seen_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DealPatch(BaseModel):
    is_favorite: bool | None = None
    is_dismissed: bool | None = None


class ScraperStartRequest(BaseModel):
    target_ids: list[int] | None = Field(default=None, description="Optional subset of target IDs to scrape")
    limit_per_target: int | None = Field(default=None, description="Max listings to fetch per target")


class ScraperStatusResponse(BaseModel):
    is_running: bool
    current_target: str | None = None
    progress: float = 0.0  # 0.0 to 1.0
    status_message: str = "Idle"
    last_run_id: int | None = None

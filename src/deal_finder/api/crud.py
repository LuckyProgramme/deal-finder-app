"""Database CRUD operations for targets, deals, and scraper runs."""

from __future__ import annotations

from datetime import datetime, timezone
import json
from typing import Sequence

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from .db_models import DealModel, ScraperRunModel, TargetModel
from .schemas import DealPatch, TargetCreate, TargetUpdate


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ============================================================================
# Target CRUD
# ============================================================================

def get_targets(
    db: Session,
    category: str | None = None,
    search: str | None = None,
) -> Sequence[TargetModel]:
    stmt = select(TargetModel)
    if category:
        stmt = stmt.where(TargetModel.category.ilike(f"%{category}%"))
    if search:
        stmt = stmt.where(TargetModel.item_name.ilike(f"%{search}%"))
    stmt = stmt.order_by(TargetModel.item_name.asc())
    return db.scalars(stmt).all()


def get_target(db: Session, target_id: int) -> TargetModel | None:
    return db.get(TargetModel, target_id)


def get_target_by_name(db: Session, item_name: str) -> TargetModel | None:
    stmt = select(TargetModel).where(TargetModel.item_name.ilike(item_name.strip()))
    return db.scalars(stmt).first()


def create_target(db: Session, target_in: TargetCreate) -> TargetModel:
    target = TargetModel(
        item_name=target_in.item_name.strip(),
        category=target_in.category.strip(),
        deal_price=target_in.deal_price,
        retail_price=target_in.retail_price,
        downsizing_keywords=target_in.downsizing_keywords.strip(),
        freebie_keywords=target_in.freebie_keywords.strip(),
        notes=target_in.notes.strip(),
        target_type=target_in.target_type,
        allow_bundle_check=target_in.allow_bundle_check,
    )
    db.add(target)
    db.commit()
    db.refresh(target)
    return target


def update_target(db: Session, target: TargetModel, target_in: TargetUpdate) -> TargetModel:
    update_data = target_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if isinstance(value, str):
            setattr(target, field, value.strip())
        else:
            setattr(target, field, value)
    target.updated_at = _utc_now()
    db.commit()
    db.refresh(target)
    return target


def delete_target(db: Session, target: TargetModel) -> None:
    db.delete(target)
    db.commit()


def seed_default_targets_if_empty(db: Session) -> int:
    """Populate default target hardware/games if the targets table is empty."""
    existing_count = db.query(TargetModel).count()
    if existing_count > 0:
        return 0

    defaults = [
        TargetCreate(
            item_name="Nintendo Switch OLED",
            category="Consoles",
            deal_price=10000.0,
            retail_price=16000.0,
            downsizing_keywords="v1, v2, lite",
            freebie_keywords="games, case, pouch, pro controller",
            notes="Look for complete in box OLED white or neon.",
            target_type="Hardware",
            allow_bundle_check=True,
        ),
        TargetCreate(
            item_name="PlayStation 5 Disc",
            category="Consoles",
            deal_price=22000.0,
            retail_price=30000.0,
            downsizing_keywords="digital, slim digital",
            freebie_keywords="controller, games, charging dock",
            notes="Ensure disc drive functional and cables included.",
            target_type="Hardware",
            allow_bundle_check=True,
        ),
        TargetCreate(
            item_name="Steam Deck 512GB OLED",
            category="Handhelds",
            deal_price=28000.0,
            retail_price=36000.0,
            downsizing_keywords="64gb, 256gb, lcd",
            freebie_keywords="dock, case, screen protector, sd card",
            notes="Verify battery health and screen condition.",
            target_type="Hardware",
            allow_bundle_check=True,
        ),
        TargetCreate(
            item_name="Zelda Tears of the Kingdom",
            category="Games",
            deal_price=1800.0,
            retail_price=2800.0,
            downsizing_keywords="",
            freebie_keywords="",
            notes="Nintendo Switch cartridge with case.",
            target_type="Game",
            allow_bundle_check=False,
        ),
    ]

    for item in defaults:
        create_target(db, item)

    return len(defaults)


# ============================================================================
# Deal CRUD
# ============================================================================

def get_deals(
    db: Session,
    category: str | None = None,
    only_favorites: bool = False,
    include_dismissed: bool = False,
    search: str | None = None,
) -> Sequence[DealModel]:
    stmt = select(DealModel)
    if not include_dismissed:
        stmt = stmt.where(DealModel.is_dismissed.is_(False))
    if only_favorites:
        stmt = stmt.where(DealModel.is_favorite.is_(True))
    if category:
        stmt = stmt.where(DealModel.category.ilike(f"%{category}%"))
    if search:
        search_pattern = f"%{search}%"
        stmt = stmt.where(
            DealModel.title.ilike(search_pattern)
            | DealModel.matched_item.ilike(search_pattern)
            | DealModel.description.ilike(search_pattern)
        )

    # Order by highest savings first, then newest
    stmt = stmt.order_by(desc(DealModel.savings), desc(DealModel.last_seen_at))
    return db.scalars(stmt).all()


def get_deal(db: Session, deal_id: str) -> DealModel | None:
    return db.get(DealModel, deal_id)


def patch_deal(db: Session, deal: DealModel, patch: DealPatch) -> DealModel:
    patch_data = patch.model_dump(exclude_unset=True)
    for field, value in patch_data.items():
        setattr(deal, field, value)
    db.commit()
    db.refresh(deal)
    return deal


def upsert_deal(
    db: Session,
    deal_dict: dict,
) -> DealModel:
    deal_id = str(deal_dict["id"])
    deal = db.get(DealModel, deal_id)
    now = _utc_now()

    issues_str = json.dumps(deal_dict.get("issues", []))
    freebies_str = json.dumps(deal_dict.get("freebies", []))

    if deal:
        deal.title = deal_dict.get("title", deal.title)
        deal.price = deal_dict.get("price", deal.price)
        deal.deal_price = deal_dict.get("deal_price", deal.deal_price)
        deal.retail_price = deal_dict.get("retail_price", deal.retail_price)
        deal.savings = deal_dict.get("savings", deal.savings)
        deal.matched_item = deal_dict.get("matched_item", deal.matched_item)
        deal.condition = deal_dict.get("condition", deal.condition)
        deal.description = deal_dict.get("description", deal.description)
        deal.link = deal_dict.get("link", deal.link)
        deal.seller = deal_dict.get("seller", deal.seller)
        deal.category = deal_dict.get("category", deal.category)
        deal.thumbnail_url = deal_dict.get("thumbnail_url", deal.thumbnail_url)
        deal.issues_json = issues_str
        deal.freebies_json = freebies_str
        deal.confidence = deal_dict.get("confidence", deal.confidence)
        deal.audit_source = deal_dict.get("audit_source", deal.audit_source)
        deal.last_seen_at = now
    else:
        deal = DealModel(
            id=deal_id,
            title=deal_dict["title"],
            price=deal_dict.get("price"),
            deal_price=deal_dict["deal_price"],
            retail_price=deal_dict.get("retail_price"),
            savings=deal_dict.get("savings"),
            matched_item=deal_dict["matched_item"],
            condition=deal_dict.get("condition", ""),
            description=deal_dict.get("description", ""),
            link=deal_dict.get("link", ""),
            seller=deal_dict.get("seller", ""),
            category=deal_dict.get("category", ""),
            thumbnail_url=deal_dict.get("thumbnail_url"),
            issues_json=issues_str,
            freebies_json=freebies_str,
            confidence=deal_dict.get("confidence", 0),
            audit_source=deal_dict.get("audit_source", "local_fallback"),
            first_seen_at=now,
            last_seen_at=now,
        )
        db.add(deal)

    db.commit()
    db.refresh(deal)
    return deal

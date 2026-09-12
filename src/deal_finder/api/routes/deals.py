"""API endpoints for Deal Explorer and deal actions."""

from __future__ import annotations

from typing import Sequence
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..crud import get_deal, get_deals, patch_deal
from ..database import get_db
from ..schemas import DealPatch, DealResponse

router = APIRouter(prefix="/api/deals", tags=["Deals"])


@router.get("", response_model=list[DealResponse])
def list_deals(
    category: str | None = Query(None, description="Filter deals by category"),
    only_favorites: bool = Query(False, description="Filter only favorited deals"),
    include_dismissed: bool = Query(False, description="Include dismissed deals"),
    search: str | None = Query(None, description="Search across title, description, or matched item"),
    db: Session = Depends(get_db),
) -> Sequence[DealResponse]:
    """List discovered deals according to active filters."""
    return get_deals(
        db,
        category=category,
        only_favorites=only_favorites,
        include_dismissed=include_dismissed,
        search=search,
    )


@router.get("/{deal_id}", response_model=DealResponse)
def read_deal(deal_id: str, db: Session = Depends(get_db)) -> DealResponse:
    """Get single deal details."""
    deal = get_deal(db, deal_id)
    if not deal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return deal


@router.patch("/{deal_id}", response_model=DealResponse)
def update_deal(
    deal_id: str,
    patch: DealPatch,
    db: Session = Depends(get_db),
) -> DealResponse:
    """Update deal state (e.g. toggle favorite or dismiss)."""
    deal = get_deal(db, deal_id)
    if not deal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return patch_deal(db, deal, patch)


@router.post("/{deal_id}/favorite", response_model=DealResponse)
def toggle_favorite(deal_id: str, db: Session = Depends(get_db)) -> DealResponse:
    """Convenience toggle for favoriting a deal."""
    deal = get_deal(db, deal_id)
    if not deal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return patch_deal(db, deal, DealPatch(is_favorite=not deal.is_favorite))


@router.post("/{deal_id}/dismiss", response_model=DealResponse)
def dismiss_deal(deal_id: str, db: Session = Depends(get_db)) -> DealResponse:
    """Convenience endpoint to dismiss a deal from the explorer."""
    deal = get_deal(db, deal_id)
    if not deal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return patch_deal(db, deal, DealPatch(is_dismissed=True))

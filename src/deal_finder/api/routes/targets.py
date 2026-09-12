"""API endpoints for Price List Targets CRUD."""

from __future__ import annotations

from typing import Sequence
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..crud import (
    create_target,
    delete_target,
    get_target,
    get_target_by_name,
    get_targets,
    update_target,
)
from ..database import get_db
from ..schemas import TargetCreate, TargetResponse, TargetUpdate

router = APIRouter(prefix="/api/targets", tags=["Price List Targets"])


@router.get("", response_model=list[TargetResponse])
def list_targets(
    category: str | None = Query(None, description="Filter targets by category"),
    search: str | None = Query(None, description="Search item name"),
    db: Session = Depends(get_db),
) -> Sequence[TargetResponse]:
    """List all configured price targets."""
    return get_targets(db, category=category, search=search)


@router.get("/{target_id}", response_model=TargetResponse)
def read_target(target_id: int, db: Session = Depends(get_db)) -> TargetResponse:
    """Get a single target by ID."""
    target = get_target(db, target_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target not found")
    return target


@router.post("", response_model=TargetResponse, status_code=status.HTTP_201_CREATED)
def add_target(target_in: TargetCreate, db: Session = Depends(get_db)) -> TargetResponse:
    """Create a new price target."""
    existing = get_target_by_name(db, target_in.item_name)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Target with name '{target_in.item_name}' already exists",
        )
    return create_target(db, target_in)


@router.put("/{target_id}", response_model=TargetResponse)
def edit_target(
    target_id: int,
    target_in: TargetUpdate,
    db: Session = Depends(get_db),
) -> TargetResponse:
    """Update an existing target."""
    target = get_target(db, target_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target not found")
    return update_target(db, target, target_in)


@router.delete("/{target_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_target(target_id: int, db: Session = Depends(get_db)) -> None:
    """Delete a target."""
    target = get_target(db, target_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target not found")
    delete_target(db, target)

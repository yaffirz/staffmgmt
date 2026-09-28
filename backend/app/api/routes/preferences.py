"""Per-user UI preferences (self-service). Each user reads/writes only their own
rows in `user_preferences` — e.g. which employee-list columns they hide."""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import get_current_user
from app.core.database import get_session
from app.models.models import UserPreferences, utcnow
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/me/preferences", tags=["preferences"])


class PrefValue(BaseModel):
    value: dict = {}


class PrefRead(BaseModel):
    key: str
    value: dict | None = None


@router.get("/{key}", response_model=PrefRead)
def read_preference(
    key: str,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """The current user's saved value for a preference key (null if unset)."""
    row = session.exec(
        select(UserPreferences).where(
            UserPreferences.user_id == current.user_id,
            UserPreferences.pref_key == key,
        )
    ).first()
    return PrefRead(key=key, value=row.value if row else None)


@router.put("/{key}", response_model=PrefRead)
def write_preference(
    key: str,
    payload: PrefValue,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Upsert the current user's value for a preference key."""
    row = session.exec(
        select(UserPreferences).where(
            UserPreferences.user_id == current.user_id,
            UserPreferences.pref_key == key,
        )
    ).first()
    if row is None:
        row = UserPreferences(
            user_id=current.user_id, pref_key=key, value=payload.value
        )
    else:
        row.value = payload.value
        row.updated_at = utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return PrefRead(key=key, value=row.value)

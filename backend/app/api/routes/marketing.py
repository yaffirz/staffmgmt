"""Public marketing-block endpoint (login-screen promo content).

Stored in `app_settings` (managed from the admin Settings screen) and served
UNAUTHENTICATED so the login screen can render it before anyone signs in — the
same pattern as the maintenance-status endpoint. Single-tenant (tenant_id = 1)
for Phase 1; make tenant-aware alongside the rest when multi-tenant lands.
"""
from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.core.app_settings import get_bool, get_setting
from app.core.database import get_session
from app.schemas.marketing import MarketingContent

router = APIRouter(prefix="/api/v1/marketing", tags=["marketing"])

_TENANT_ID = 1
_ALLOWED_TYPES = {"text", "image", "embed"}


@router.get("", response_model=MarketingContent)
def marketing_content(session: Session = Depends(get_session)):
    """Current login-screen marketing block (public — no auth required)."""
    enabled = get_bool(session, _TENANT_ID, "marketing_enabled", False)
    mtype = (get_setting(session, _TENANT_ID, "marketing_type") or "text").lower()
    if mtype not in _ALLOWED_TYPES:
        mtype = "text"
    title = get_setting(session, _TENANT_ID, "marketing_title") or ""
    content = get_setting(session, _TENANT_ID, "marketing_content") or ""
    return MarketingContent(enabled=enabled, type=mtype, title=title, content=content)

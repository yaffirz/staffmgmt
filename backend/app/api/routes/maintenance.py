"""Public maintenance-status endpoint.

The maintenance window is stored in `app_settings` (managed from the admin
Settings screen). This endpoint is intentionally UNAUTHENTICATED so the frontend
can learn the state before a user logs in and render the maintenance page.

Phase 1 is single-tenant (tenant_id = 1), so the public read resolves settings
for tenant 1. Make this tenant-aware alongside the rest of the app when
multi-tenant lands.
"""
from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.core.app_settings import get_bool, get_setting
from app.core.database import get_session
from app.schemas.maintenance import MaintenanceStatus

router = APIRouter(prefix="/api/v1/maintenance", tags=["maintenance"])

_TENANT_ID = 1


@router.get("/status", response_model=MaintenanceStatus)
def maintenance_status(session: Session = Depends(get_session)):
    """Current maintenance state (public — no auth required)."""
    active = get_bool(session, _TENANT_ID, "maintenance_mode", False)
    message = get_setting(session, _TENANT_ID, "maintenance_message") or ""
    until = get_setting(session, _TENANT_ID, "maintenance_until") or None
    return MaintenanceStatus(active=active, message=message, until=until)

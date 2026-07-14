from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session

from app.api.deps import require_roles
from app.core.app_settings import DEFAULTS, get_setting, set_setting
from app.core.database import get_session
from app.models.models import AuditLogs
from app.schemas.auth import CurrentUser
from app.schemas.settings import SettingRead, SettingUpdate

router = APIRouter(prefix="/api/v1/settings", tags=["settings"])

# App settings (feature toggles) are managed by these roles.
ADMIN_ROLES = ("Super Admin", "Admin")


@router.get("/{key}", response_model=SettingRead)
def read_setting(
    key: str,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Read a setting's effective value (stored value, else known default)."""
    value = get_setting(session, current.tenant_id, key)
    if value is None:
        raise HTTPException(status_code=404, detail=f"Unknown setting '{key}'.")
    return SettingRead(key=key, value=value)


@router.patch("/{key}", response_model=SettingRead)
def update_setting(
    key: str,
    payload: SettingUpdate,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Upsert a setting's value (Admin / Super Admin only)."""
    if key not in DEFAULTS:
        raise HTTPException(status_code=404, detail=f"Unknown setting '{key}'.")

    row, old = set_setting(session, current.tenant_id, key, payload.value)
    session.commit()
    session.refresh(row)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="app_settings",
            record_id=str(row.setting_id),
            old_value={"key": key, "value": old},
            new_value={"key": key, "value": row.value},
        )
    )
    session.commit()

    return SettingRead(key=key, value=row.value)

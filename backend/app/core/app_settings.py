"""Shared access to per-tenant app settings (feature toggles, etc.).

Values are stored as strings. Known keys carry a default so a missing row still
resolves to a sensible value — the settings router upserts a row on first change.
"""
from typing import Optional

from sqlmodel import Session, select

from app.models.models import AppSettings

# Known settings and their default (string) values.
DEFAULTS: dict[str, str] = {
    # Standing-rule toggle: may an Area Manager move staff between their stores?
    "area_managers_can_move": "true",
}


def get_setting(session: Session, tenant_id: int, key: str) -> Optional[str]:
    """Return the stored value for a key, or its known default, or None."""
    row = session.exec(
        select(AppSettings).where(
            AppSettings.tenant_id == tenant_id, AppSettings.key == key
        )
    ).first()
    if row is not None:
        return row.value
    return DEFAULTS.get(key)


def get_bool(session: Session, tenant_id: int, key: str, default: bool = False) -> bool:
    val = get_setting(session, tenant_id, key)
    if val is None:
        return default
    return val.strip().lower() in ("true", "1", "yes", "on")


def set_setting(
    session: Session, tenant_id: int, key: str, value: str
) -> tuple[AppSettings, Optional[str]]:
    """Upsert a setting. Returns (row, old_value_or_None). Caller commits/audits."""
    row = session.exec(
        select(AppSettings).where(
            AppSettings.tenant_id == tenant_id, AppSettings.key == key
        )
    ).first()
    old = row.value if row is not None else None
    if row is None:
        row = AppSettings(tenant_id=tenant_id, key=key, value=value)
        session.add(row)
    else:
        row.value = value
        session.add(row)
    return row, old

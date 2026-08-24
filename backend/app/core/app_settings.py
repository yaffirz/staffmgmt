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
    # Standing-rule toggle: is the staff-notes feature enabled (writing notes)?
    "staff_notes_enabled": "true",
    # Maintenance mode: when on, field users (HR / Area Manager) see the
    # maintenance page; back-office roles (Super Admin / Admin / IT) keep working.
    "maintenance_mode": "false",
    # Optional custom message shown on the maintenance page (empty = default text).
    "maintenance_message": "",
    # Optional ISO-8601 end time for the maintenance window (empty = no ETA).
    # The Settings UI turns a chosen duration into this absolute timestamp.
    "maintenance_until": "",
    # Login-screen marketing block (public). When enabled, shown on login.
    "marketing_enabled": "false",
    # Content type: text | image | embed (embed = a video/other-media URL).
    "marketing_type": "text",
    # Optional heading shown above the content.
    "marketing_title": "",
    # The text body, an image URL, or an embeddable media URL (per type).
    "marketing_content": "",
    # Self-service registration: off by default (public site + email not yet
    # configured). When on, the login screen shows a "Create account" link.
    "registration_enabled": "false",
    # Scheduled database backups: off | daily | weekly, at backup_time (HH:MM,
    # server time), keeping the most recent `backup_retention` scheduled dumps.
    "backup_schedule": "off",
    "backup_time": "02:00",
    "backup_retention": "10",
    # Show the "Get the Android app" download to signed-in users (when an APK
    # has been published to APP_DIST_DIR).
    "app_download_enabled": "true",
    # New-hire wizard: allow adding a staffer with no email via an "email
    # currently unavailable" checkbox (the row is then flagged for HR).
    "email_unavailable_enabled": "true",
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

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
    # Require a real pay rate before a row can be marked reviewed: a pay rate of
    # 0.00 flags the row amber and blocks review until it's fixed.
    "payrate_required_for_review": "true",
    # --- Outgoing email (SMTP) -------------------------------------------
    # Master switch: when off, send_email() is a no-op that only logs (the
    # historical stub behaviour). Turn on once the server settings below are
    # filled in and a test email has been received.
    "email_enabled": "false",
    # SMTP server. For Turbify (Yahoo business mail) this is
    # smtp.bizmail.yahoo.com. Consumer Yahoo is smtp.mail.yahoo.com.
    "email_smtp_host": "",
    # Port: 465 with SSL, or 587 with STARTTLS.
    "email_smtp_port": "465",
    # "true" = implicit SSL (port 465); "false" = STARTTLS (port 587).
    "email_use_ssl": "true",
    # Login user — usually the full mailbox address. For Yahoo/Turbify use an
    # app-specific password (below), not the account's main password.
    "email_username": "",
    # SMTP password / app password. Sensitive: never returned to the client
    # (the config API reports only whether it is set).
    "email_password": "",
    # The From address. Must be a real mailbox on your domain (Yahoo/Turbify
    # reject sending "from" an address you don't own).
    "email_from": "",
    # Optional display name shown alongside the From address.
    "email_from_name": "Staff Portal",
    # Public base URL of the app, used to build absolute links in emails (e.g.
    # the password-reset link). Empty = derive from the request (works when the
    # app is reached directly; set this when behind a tunnel/proxy).
    "app_base_url": "",
    # --- Email content / templates --------------------------------------
    # Format outgoing emails as HTML (multipart: an HTML part + a plain-text
    # fallback). Enables a formatted signature (bold/colour/links/images). When
    # off, emails are plain text (the historical behaviour).
    "email_html": "false",
    # A signature appended to platform emails. Placed wherever <signature>
    # appears in a template (and after the body of non-templated emails). May be
    # HTML when email_html is on.
    "email_signature": "",
    # Password-reset email. Supports the tags <username>, <email>,
    # <reset_link>, <expiry_minutes>, <signature>, <from_name>, <site_url>.
    "email_reset_subject": "Reset your Staff Portal password",
    "email_reset_body": (
        "Hi <username>,\n\n"
        "We received a request to reset your Staff Portal password.\n\n"
        "Reset it here (link valid for <expiry_minutes> minutes):\n"
        "<reset_link>\n\n"
        "If you didn't request this, you can ignore this email — your "
        "password won't change.\n\n"
        "<signature>"
    ),
}

# Placeholder tags available in email templates, for the admin UI hint.
EMAIL_TEMPLATE_TAGS = (
    "username",
    "email",
    "reset_link",
    "expiry_minutes",
    "signature",
    "from_name",
    "site_url",
)

# Email settings that are safe to expose to admins via the config API (the
# password is deliberately excluded — see routes/email_admin.py).
EMAIL_SETTING_KEYS = (
    "email_enabled",
    "email_smtp_host",
    "email_smtp_port",
    "email_use_ssl",
    "email_username",
    "email_from",
    "email_from_name",
)


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

"""Admin management of the outgoing-email (SMTP) server settings.

Config is stored in app_settings so the server can be changed from the UI. The
SMTP password is write-only: it is saved but never returned (the read reports
only `password_set`). Restricted to Super Admin — these are credentials.
"""
from fastapi import APIRouter, Depends
from sqlmodel import Session

from app.api.deps import require_roles
from app.core.app_settings import get_bool, get_setting, set_setting
from app.core.database import get_session
from app.core.email import _deliver, load_email_config
from app.models.models import AuditLogs
from app.schemas.auth import CurrentUser
from app.schemas.email import (
    EmailConfigRead,
    EmailConfigUpdate,
    TestEmailRequest,
    TestEmailResult,
)

router = APIRouter(prefix="/api/v1/email", tags=["email"])

# SMTP credentials — Super Admin only.
EMAIL_ADMIN_ROLES = ("Super Admin",)


def _read_config(session: Session, tenant_id: int) -> EmailConfigRead:
    def _s(key: str) -> str:
        return (get_setting(session, tenant_id, key) or "").strip()

    try:
        port = int(_s("email_smtp_port") or "465")
    except ValueError:
        port = 465
    return EmailConfigRead(
        email_enabled=get_bool(session, tenant_id, "email_enabled"),
        email_smtp_host=_s("email_smtp_host"),
        email_smtp_port=port,
        email_use_ssl=get_bool(session, tenant_id, "email_use_ssl", default=True),
        email_username=_s("email_username"),
        email_from=_s("email_from"),
        email_from_name=_s("email_from_name") or "Staff Portal",
        password_set=bool(get_setting(session, tenant_id, "email_password") or ""),
    )


@router.get("/config", response_model=EmailConfigRead)
def read_email_config(
    current: CurrentUser = Depends(require_roles(*EMAIL_ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Current SMTP settings (password never returned — only `password_set`)."""
    return _read_config(session, current.tenant_id)


@router.put("/config", response_model=EmailConfigRead)
def update_email_config(
    payload: EmailConfigUpdate,
    current: CurrentUser = Depends(require_roles(*EMAIL_ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Update SMTP settings. Only provided fields change; a blank/omitted
    `email_password` keeps the stored one."""
    tid = current.tenant_id
    changed: list[str] = []

    def _apply(key: str, value: str) -> None:
        set_setting(session, tid, key, value)
        changed.append(key)

    if payload.email_enabled is not None:
        _apply("email_enabled", "true" if payload.email_enabled else "false")
    if payload.email_smtp_host is not None:
        _apply("email_smtp_host", payload.email_smtp_host.strip())
    if payload.email_smtp_port is not None:
        _apply("email_smtp_port", str(payload.email_smtp_port))
    if payload.email_use_ssl is not None:
        _apply("email_use_ssl", "true" if payload.email_use_ssl else "false")
    if payload.email_username is not None:
        _apply("email_username", payload.email_username.strip())
    if payload.email_from is not None:
        _apply("email_from", payload.email_from.strip())
    if payload.email_from_name is not None:
        _apply("email_from_name", payload.email_from_name.strip())
    # Password: only when a non-empty value is supplied (blank = keep existing).
    if payload.email_password:
        _apply("email_password", payload.email_password)

    session.commit()

    if changed:
        # Audit which keys changed — never the secret values.
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="UPDATE",
                affected_table="app_settings",
                record_id="email",
                old_value=None,
                new_value={"email_settings_changed": changed},
            )
        )
        session.commit()

    return _read_config(session, tid)


@router.post("/test", response_model=TestEmailResult)
def send_test_email(
    payload: TestEmailRequest,
    current: CurrentUser = Depends(require_roles(*EMAIL_ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Send a test message using the currently stored config, surfacing any SMTP
    error so the admin can fix it. Works even while email_enabled is off, as long
    as the server settings are filled in, so it can be verified before going live."""
    cfg = load_email_config(session, current.tenant_id)
    if not cfg.configured:
        return TestEmailResult(
            ok=False,
            detail="Fill in the SMTP host and From address (and Save) first.",
        )
    try:
        _deliver(
            cfg,
            str(payload.to),
            "Staff Portal — test email",
            "This is a test email from your Staff Portal. "
            "If you received it, outgoing email is working.",
        )
    except Exception as exc:  # noqa: BLE001 — report the reason to the admin.
        return TestEmailResult(ok=False, detail=f"{type(exc).__name__}: {exc}")

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="app_settings",
            record_id="email",
            old_value=None,
            new_value={"email_test_sent_to": str(payload.to)},
        )
    )
    session.commit()
    return TestEmailResult(ok=True, detail=f"Test email sent to {payload.to}.")

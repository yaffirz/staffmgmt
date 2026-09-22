"""Outgoing email.

Delivery config lives in `app_settings` (managed from Admin → Email), so the
server can be pointed at a new provider without a redeploy. When email is
disabled or unconfigured, `send_email` is a no-op that only logs — the same
best-effort contract callers (e.g. registration) have always relied on.

`_deliver` does the real SMTP work and RAISES on failure; `send_email` swallows
those (best-effort), while the admin "send test email" endpoint calls `_deliver`
directly so it can surface the actual error.
"""
import logging
import smtplib
import ssl
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import formataddr

from sqlmodel import Session

from app.core.app_settings import get_bool, get_setting
from app.core.config import settings as app_config
from app.core.database import engine

logger = logging.getLogger("app.email")


@dataclass
class EmailConfig:
    enabled: bool
    host: str
    port: int
    use_ssl: bool
    username: str
    password: str
    from_addr: str
    from_name: str

    @property
    def configured(self) -> bool:
        """Enough to attempt a send (host + a From address)."""
        return bool(self.host and self.from_addr)


def load_email_config(session: Session, tenant_id: int) -> EmailConfig:
    """Read the SMTP config for a tenant from app_settings."""
    def _s(key: str) -> str:
        return (get_setting(session, tenant_id, key) or "").strip()

    try:
        port = int(_s("email_smtp_port") or "465")
    except ValueError:
        port = 465
    return EmailConfig(
        enabled=get_bool(session, tenant_id, "email_enabled"),
        host=_s("email_smtp_host"),
        port=port,
        use_ssl=get_bool(session, tenant_id, "email_use_ssl", default=True),
        username=_s("email_username"),
        password=(get_setting(session, tenant_id, "email_password") or ""),
        from_addr=_s("email_from") or _s("email_username"),
        from_name=_s("email_from_name") or "Staff Portal",
    )


def _deliver(cfg: EmailConfig, to: str, subject: str, body: str) -> None:
    """Send one plaintext email via SMTP. Raises on any failure."""
    if not cfg.configured:
        raise RuntimeError("Email server is not configured (host/from missing).")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = formataddr((cfg.from_name, cfg.from_addr))
    msg["To"] = to
    msg.set_content(body)

    context = ssl.create_default_context()
    if cfg.use_ssl:
        with smtplib.SMTP_SSL(cfg.host, cfg.port, context=context, timeout=30) as s:
            if cfg.username:
                s.login(cfg.username, cfg.password)
            s.send_message(msg)
    else:
        with smtplib.SMTP(cfg.host, cfg.port, timeout=30) as s:
            s.ehlo()
            s.starttls(context=context)
            s.ehlo()
            if cfg.username:
                s.login(cfg.username, cfg.password)
            s.send_message(msg)


def send_email(to: str, subject: str, body: str) -> None:
    """Deliver an email, best-effort. Never raises — a failure (or email being
    disabled/unconfigured) is logged and swallowed so callers treat email as
    optional. For paths that need to know whether it worked, use `_deliver`."""
    tenant_id = app_config.DEFAULT_TENANT_ID
    with Session(engine) as session:
        cfg = load_email_config(session, tenant_id)

    if not cfg.enabled or not cfg.configured:
        logger.info(
            "EMAIL (not sent: %s) to=%s | %s",
            "disabled" if not cfg.enabled else "unconfigured",
            to,
            subject,
        )
        return
    try:
        _deliver(cfg, to, subject, body)
        logger.info("EMAIL sent to=%s | %s", to, subject)
    except Exception as exc:  # noqa: BLE001 — best-effort; log and move on.
        logger.warning("EMAIL failed to=%s | %s | %s", to, subject, exc)

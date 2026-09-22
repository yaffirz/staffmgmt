"""Outgoing email.

Delivery config lives in `app_settings` (managed from Admin → Email), so the
server can be pointed at a new provider without a redeploy. When email is
disabled or unconfigured, `send_email` is a no-op that only logs — the same
best-effort contract callers (e.g. registration) have always relied on.

`_deliver` does the real SMTP work and RAISES on failure; `send_email` swallows
those (best-effort), while the admin "send test email" endpoint calls `_deliver`
directly so it can surface the actual error.
"""
import html as htmllib
import logging
import re
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

# Placeholder tag like <username>. Only letters/underscore-led names match, so
# ordinary angle-bracket text (URLs, "<3") is left untouched.
_TAG_RE = re.compile(r"<([a-z_][a-z0-9_]*)>")


def render_template(text: str, context: dict) -> str:
    """Replace <tag> placeholders from `context` in one pass (so a substituted
    value — e.g. the signature — isn't itself re-scanned). Unknown tags are left
    as-is."""
    if not text:
        return ""
    return _TAG_RE.sub(
        lambda m: str(context.get(m.group(1), m.group(0))), text
    )


def signature_for(session: Session, tenant_id: int) -> str:
    """The configured email signature (may be empty; may be HTML)."""
    return (get_setting(session, tenant_id, "email_signature") or "").strip()


# --- HTML helpers --------------------------------------------------------
# A private-use sentinel marks where the (possibly HTML) signature goes, so the
# surrounding plain text can be HTML-escaped without escaping the signature.
_SIG_SENTINEL = "SIGNATURE"
_URL_RE = re.compile(r"(https?://[^\s<]+)")


def _looks_like_html(s: str) -> bool:
    """True if the text already contains real HTML tags (so we don't re-escape
    author-written HTML)."""
    return bool(re.search(r"<[a-zA-Z!/][^>]*>", s or ""))


def _escape_linkify_br(text: str) -> str:
    """Plain text → safe HTML: escape, linkify http(s) URLs, newlines to <br>."""
    esc = htmllib.escape(text)
    esc = _URL_RE.sub(r'<a href="\1">\1</a>', esc)
    return esc.replace("\n", "<br>\n")


def html_to_text(html_str: str) -> str:
    """Crude HTML → plain text for the multipart fallback part."""
    t = re.sub(r"(?i)<br\s*/?>", "\n", html_str or "")
    t = re.sub(r"(?i)</(p|div|tr|h[1-6]|li)>", "\n", t)
    t = re.sub(r"<[^>]+>", "", t)
    return htmllib.unescape(t).strip()


def _wrap_html(inner: str) -> str:
    return (
        '<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;'
        f'color:#111;line-height:1.5">{inner}</div>'
    )


def compose_message(
    session: Session,
    tenant_id: int,
    body_template: str,
    context: dict,
) -> tuple[str, str | None]:
    """Render a body template (which may contain <signature> and other tags) into
    a `(text, html_or_None)` pair, honouring the `email_html` toggle.

    - Plain-text mode: returns the rendered text (signature reduced to text) and
      None.
    - HTML mode: the signature is inserted as raw HTML at <signature>; the rest of
      the body is escaped + linkified unless the author already wrote HTML. The
      text part is derived from the HTML so both stay in sync.
    """
    sig = signature_for(session, tenant_id)
    html_mode = get_bool(session, tenant_id, "email_html")

    if not html_mode:
        sig_text = html_to_text(sig) if _looks_like_html(sig) else sig
        text = render_template(body_template, {**context, "signature": sig_text})
        return text, None

    rendered = render_template(
        body_template, {**context, "signature": _SIG_SENTINEL}
    )
    core = rendered.replace(_SIG_SENTINEL, "")
    if _looks_like_html(core):
        inner = rendered.replace(_SIG_SENTINEL, sig)
    else:
        inner = _escape_linkify_br(rendered).replace(_SIG_SENTINEL, sig)
    html = _wrap_html(inner)
    return html_to_text(html), html


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


def _deliver(
    cfg: EmailConfig, to: str, subject: str, body: str, html: str | None = None
) -> None:
    """Send one email via SMTP. Plain text, or multipart (text + HTML) when
    `html` is given. Raises on any failure."""
    if not cfg.configured:
        raise RuntimeError("Email server is not configured (host/from missing).")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = formataddr((cfg.from_name, cfg.from_addr))
    msg["To"] = to
    msg.set_content(body)
    if html:
        msg.add_alternative(html, subtype="html")

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


def send_email(
    to: str, subject: str, body: str, html: str | None = None
) -> None:
    """Deliver an email, best-effort. Never raises — a failure (or email being
    disabled/unconfigured) is logged and swallowed so callers treat email as
    optional. Pass `html` for a multipart HTML message. For paths that need to
    know whether it worked, use `_deliver`."""
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
        _deliver(cfg, to, subject, body, html=html)
        logger.info("EMAIL sent to=%s | %s", to, subject)
    except Exception as exc:  # noqa: BLE001 — best-effort; log and move on.
        logger.warning("EMAIL failed to=%s | %s | %s", to, subject, exc)

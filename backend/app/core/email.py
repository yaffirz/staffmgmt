"""Pluggable email sender.

Sending is stubbed for now — it logs the message so the registration/confirmation
flow works end-to-end without a configured mail domain. When the owner sets up
sending (SPF/DKIM + SMTP), wire real delivery here (read EMAIL_* from settings)
and this becomes the single place that changes.
"""
import logging

logger = logging.getLogger("app.email")


def send_email(to: str, subject: str, body: str) -> None:
    """Deliver an email. Currently a no-op that logs (email sending not yet
    configured). Never raises — callers treat email as best-effort."""
    logger.info("EMAIL (stub, not sent) to=%s | %s\n%s", to, subject, body)

from typing import Optional

from pydantic import BaseModel, EmailStr


class EmailConfigRead(BaseModel):
    """Email server config as shown to admins. The password is never returned —
    only whether one is stored."""
    email_enabled: bool
    email_smtp_host: str
    email_smtp_port: int
    email_use_ssl: bool
    email_username: str
    email_from: str
    email_from_name: str
    password_set: bool


class EmailConfigUpdate(BaseModel):
    """All fields optional — only the provided ones are changed. `email_password`
    is applied only when non-empty (leave blank to keep the stored one)."""
    email_enabled: Optional[bool] = None
    email_smtp_host: Optional[str] = None
    email_smtp_port: Optional[int] = None
    email_use_ssl: Optional[bool] = None
    email_username: Optional[str] = None
    email_password: Optional[str] = None
    email_from: Optional[str] = None
    email_from_name: Optional[str] = None


class TestEmailRequest(BaseModel):
    to: EmailStr


class TestEmailResult(BaseModel):
    ok: bool
    detail: str

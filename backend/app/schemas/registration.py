from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str
    note: Optional[str] = None  # optional "who I am / desired role" free text


class RegisterResult(BaseModel):
    status: str
    message: str


class RegistrationRead(BaseModel):
    id: int
    username: str
    email: str
    status: str
    email_verified: bool
    note: Optional[str] = None
    created_at: datetime
    # Handy while email sending isn't live — the admin can open this to confirm.
    confirm_path: Optional[str] = None


class ApproveRequest(BaseModel):
    role: str
    store_id: Optional[int] = None  # Store / Foodmall
    brand_ids: Optional[List[int]] = None  # Area Manager

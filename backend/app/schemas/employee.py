from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class EmployeeCreate(BaseModel):
    # tenant_id is NOT accepted from the client — it comes from the JWT.
    # Structural / locked fields stay required at the schema level.
    payroll_id: str = Field(min_length=1)
    employee_name: str = Field(min_length=1)
    date_of_birth: date  # JSON sends "YYYY-MM-DD"; Pydantic parses it.
    primary_store_id: int
    position_id: int
    # The brand the staffer belongs to (must be one the primary store serves —
    # its own brand, or a foodmall extra brand). Optional; defaults to the store's
    # primary brand when omitted.
    brand_id: Optional[int] = None
    # Configurable fields — required-ness is enforced per the form config,
    # so they are optional at the schema level.
    email: Optional[EmailStr] = None
    # When true and no email is given, the record is created "email pending"
    # (allowed only if the email_unavailable_enabled setting is on).
    email_pending: bool = False
    payrate: Optional[float] = Field(default=None, ge=0)
    pay_currency: Optional[str] = None  # e.g. "TTD", "USD", "JAM", "XCD"
    phone_number: Optional[str] = None
    mag_code: Optional[str] = None
    country_id: Optional[int] = None
    additional_store_ids: Optional[list[int]] = None


class ReviewUpdate(BaseModel):
    reviewed: bool


class ReviewFlagUpdate(BaseModel):
    # Field keys to flag as needing review. Empty list clears the flag.
    fields: list[str] = []


class MagUpdate(BaseModel):
    mag_code: Optional[str] = None


class EmployeeRead(BaseModel):
    employee_id: int
    tenant_id: int
    payroll_id: str
    employee_name: str
    date_of_birth: date
    phone_number: Optional[str]
    email: Optional[str]  # plain str on read, not EmailStr
    email_pending: bool = False
    payrate: Optional[float]
    pay_currency: Optional[str]
    mag_code: Optional[str]
    country_id: Optional[int]
    primary_store_id: Optional[int]
    position_id: Optional[int]
    brand_id: Optional[int]  # effective brand (own, else primary store's)
    reviewed: bool
    promotion_pending_review: bool = False
    review_fields: list[str] = []  # cells an Admin/IT flagged for review
    created_at: datetime
    created_by: Optional[int] = None
    reviewed_at: Optional[datetime] = None

    # Resolved display names (option b) — populated by the endpoint.
    store_name: Optional[str] = None
    brand_name: Optional[str] = None
    position_title: Optional[str] = None
    country_name: Optional[str] = None
    created_by_name: Optional[str] = None  # username of the creator
    additional_stores: list[str] = []  # resolved additional-store names
    additional_store_ids: list[int] = []  # ids, for editing

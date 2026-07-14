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
    # Configurable fields — required-ness is enforced per the form config,
    # so they are optional at the schema level.
    email: Optional[EmailStr] = None
    payrate: Optional[float] = Field(default=None, ge=0)
    pay_currency: Optional[str] = None  # e.g. "TTD", "USD", "JAM", "XCD"
    phone_number: Optional[str] = None
    mag_code: Optional[str] = None
    country_id: Optional[int] = None
    additional_store_ids: Optional[list[int]] = None


class ReviewUpdate(BaseModel):
    reviewed: bool


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
    payrate: Optional[float]
    pay_currency: Optional[str]
    mag_code: Optional[str]
    country_id: Optional[int]
    primary_store_id: Optional[int]
    position_id: Optional[int]
    reviewed: bool
    created_at: datetime

    # Resolved display names (option b) — populated by the endpoint.
    store_name: Optional[str] = None
    brand_name: Optional[str] = None
    position_title: Optional[str] = None
    country_name: Optional[str] = None
    additional_stores: list[str] = []  # resolved additional-store names
    additional_store_ids: list[int] = []  # ids, for editing

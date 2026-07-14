from datetime import datetime

from pydantic import BaseModel


class StaffPageEmployee(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    position_title: str | None = None
    store_name: str | None = None
    brand_id: int | None = None
    brand_name: str | None = None


class NoteRead(BaseModel):
    note_id: int
    employee_id: int
    note_text: str
    author_user_id: int
    author_name: str
    created_at: datetime
    visibility_roles: list[str]
    visibility_brand_ids: list[int]
    visibility_label: str
    can_edit: bool


class NoteCreate(BaseModel):
    note_text: str
    visibility_roles: list[str] = []
    visibility_brand_ids: list[int] = []


class NoteUpdate(BaseModel):
    note_text: str | None = None
    visibility_roles: list[str] | None = None
    visibility_brand_ids: list[int] | None = None


class NoteFeedItem(BaseModel):
    note_id: int
    employee_id: int
    employee_name: str
    note_text: str
    author_user_id: int
    author_name: str
    created_at: datetime
    visibility_roles: list[str]
    visibility_brand_ids: list[int]
    visibility_label: str
    can_edit: bool

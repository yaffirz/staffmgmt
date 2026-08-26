from typing import List, Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    role: str  # primary role
    brand_ids: Optional[List[int]] = None  # only used for Area Manager
    store_id: Optional[int] = None  # only used for Store / Foodmall
    additional_roles: Optional[List[str]] = None  # Super Admin only
    must_change_password: bool = False  # force a change at next login


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    brand_ids: Optional[List[int]] = None
    store_id: Optional[int] = None  # only used for Store / Foodmall
    additional_roles: Optional[List[str]] = None  # Super Admin only
    must_change_password: Optional[bool] = None  # force a change at next login


class UserRead(BaseModel):
    user_id: int
    username: str
    email: Optional[str] = None
    role: str  # primary role
    roles: List[str] = []  # effective roles (primary + additional)
    additional_roles: List[str] = []
    brand_ids: List[int] = []
    brand_names: List[str] = []
    store_id: Optional[int] = None  # Store / Foodmall
    store_name: Optional[str] = None
    must_change_password: bool = False

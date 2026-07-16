from typing import List, Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    role: str  # primary role
    brand_ids: Optional[List[int]] = None  # only used for Area Manager
    additional_roles: Optional[List[str]] = None  # Super Admin only


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    brand_ids: Optional[List[int]] = None
    additional_roles: Optional[List[str]] = None  # Super Admin only


class UserRead(BaseModel):
    user_id: int
    username: str
    email: Optional[str] = None
    role: str  # primary role
    roles: List[str] = []  # effective roles (primary + additional)
    additional_roles: List[str] = []
    brand_ids: List[int] = []
    brand_names: List[str] = []

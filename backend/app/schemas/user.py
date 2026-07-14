from typing import List, Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    role: str
    brand_ids: Optional[List[int]] = None  # only used for Area Manager


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None
    brand_ids: Optional[List[int]] = None


class UserRead(BaseModel):
    user_id: int
    username: str
    email: Optional[str] = None
    role: str
    brand_ids: List[int] = []
    brand_names: List[str] = []

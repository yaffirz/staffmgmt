from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NotificationRead(BaseModel):
    notification_id: int
    type: str
    payload: Optional[dict] = None
    is_read: bool
    created_at: datetime


class UnreadCount(BaseModel):
    count: int

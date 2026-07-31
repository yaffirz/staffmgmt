from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class BackupRead(BaseModel):
    id: int
    filename: str
    status: str  # running | completed | failed
    kind: str  # manual | scheduled
    size_bytes: int
    created_by: Optional[int] = None
    started_at: datetime
    finished_at: Optional[datetime] = None
    error: Optional[str] = None


class ScheduleRead(BaseModel):
    schedule: str  # off | daily | weekly
    time: str  # HH:MM
    retention: int


class ScheduleUpdate(BaseModel):
    schedule: str
    time: str
    retention: int

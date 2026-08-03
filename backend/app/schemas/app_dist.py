from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AppInfo(BaseModel):
    enabled: bool  # admin toggle
    available: bool  # enabled AND an APK is published
    filename: Optional[str] = None
    size_bytes: int = 0
    updated_at: Optional[datetime] = None

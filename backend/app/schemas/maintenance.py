from typing import Optional

from pydantic import BaseModel


class MaintenanceStatus(BaseModel):
    """Public maintenance state. `until` is an ISO-8601 string or null."""

    active: bool
    message: str = ""
    until: Optional[str] = None

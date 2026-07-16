from datetime import datetime

from pydantic import BaseModel


class StatusChangeRequest(BaseModel):
    action_type: str  # PROMOTION | DEMOTION | TERMINATION | REACTIVATION
    to_position_id: int | None = None  # required for PROMOTION / DEMOTION
    reason: str | None = None


class StatusLogItem(BaseModel):
    log_id: int
    employee_id: int
    employee_name: str
    action_type: str
    details: dict = {}
    processed_by: int
    processed_by_name: str
    timestamp: datetime
    summary: str

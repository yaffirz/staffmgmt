from datetime import datetime

from pydantic import BaseModel


class AuditLogRead(BaseModel):
    audit_id: int
    user_id: int
    user_name: str
    action: str
    affected_table: str
    record_id: str
    old_value: dict | None = None
    new_value: dict | None = None
    timestamp: datetime
    summary: str

"""Admin mini-console — a read view over the audit_logs written across the app
(standing rule #3). Super Admin / Admin only."""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import AuditLogs, Users
from app.schemas.audit import AuditLogRead
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/audit-logs", tags=["audit"])

ADMIN_ROLES = ("Super Admin", "Admin")


def _summary(log: AuditLogs) -> str:
    verb = {"INSERT": "Created", "UPDATE": "Updated", "DELETE": "Deleted"}.get(
        log.action, log.action.title()
    )
    return f"{verb} {log.affected_table} #{log.record_id}"


@router.get("", response_model=list[AuditLogRead])
def list_audit_logs(
    table: Optional[str] = Query(None, description="Filter by affected table"),
    limit: int = Query(200, ge=1, le=500),
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Recent audit-log entries, newest first."""
    query = select(AuditLogs).order_by(AuditLogs.timestamp.desc())
    if table:
        query = query.where(AuditLogs.affected_table == table)
    rows = session.exec(query.limit(limit)).all()

    names = {}
    if rows:
        names = {
            u.user_id: u.username
            for u in session.exec(
                select(Users).where(
                    Users.user_id.in_({r.user_id for r in rows})
                )
            ).all()
        }

    return [
        AuditLogRead(
            audit_id=r.audit_id,
            user_id=r.user_id,
            user_name=names.get(r.user_id, f"user {r.user_id}"),
            action=r.action,
            affected_table=r.affected_table,
            record_id=r.record_id,
            old_value=r.old_value,
            new_value=r.new_value,
            timestamp=r.timestamp,
            summary=_summary(r),
        )
        for r in rows
    ]

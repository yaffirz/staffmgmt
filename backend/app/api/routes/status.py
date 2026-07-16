"""Phase 3 — staff status changes: promote / demote / terminate / reactivate.

Each change updates the employee, appends to `staff_status_log`, notifies the IT
role, and writes an audit row. The staff page shows the per-employee history; the
"Status Changes" dashboard tile shows a feed across all staff.
"""
from fastapi import APIRouter, Depends, HTTPException, status as http_status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import (
    AuditLogs,
    Employees,
    Notifications,
    Positions,
    StaffStatusLog,
    Stores,
    Users,
)
from app.schemas.auth import CurrentUser
from app.schemas.status import StatusChangeRequest, StatusLogItem

router = APIRouter(prefix="/api/v1/staff", tags=["status"])

# Who may perform status changes (matches the "Status Changes" dashboard tile).
STATUS_ROLES = ("Super Admin", "Admin", "HR")

_NOTIFY_TYPE = {
    "PROMOTION": "STAFF_PROMOTED",
    "DEMOTION": "STAFF_DEMOTED",
    "TERMINATION": "STAFF_TERMINATED",
    "REACTIVATION": "STAFF_REACTIVATED",
}


def _summary(action_type: str, details: dict | None) -> str:
    d = details or {}
    to_title = d.get("to_position_title")
    if action_type == "PROMOTION":
        return f"Promoted to {to_title}" if to_title else "Promoted"
    if action_type == "DEMOTION":
        return f"Changed to {to_title}" if to_title else "Position changed"
    if action_type == "TERMINATION":
        return "Terminated"
    if action_type == "REACTIVATION":
        return "Reactivated"
    if action_type == "TRANSFER":
        to_store = d.get("to_store_name")
        return f"Transferred to {to_store}" if to_store else "Transferred store"
    return action_type.title()


def _user_names(session: Session, ids: set[int]) -> dict[int, str]:
    ids = {i for i in ids if i is not None}
    if not ids:
        return {}
    return {
        u.user_id: u.username
        for u in session.exec(select(Users).where(Users.user_id.in_(ids))).all()
    }


def _to_item(
    log: StaffStatusLog, employee_name: str, processor_name: str
) -> StatusLogItem:
    return StatusLogItem(
        log_id=log.log_id,
        employee_id=log.employee_id,
        employee_name=employee_name,
        action_type=log.action_type,
        details=log.details or {},
        processed_by=log.processed_by,
        processed_by_name=processor_name,
        timestamp=log.timestamp,
        summary=_summary(log.action_type, log.details),
    )


@router.post(
    "/{employee_id}/status",
    response_model=StatusLogItem,
    status_code=http_status.HTTP_201_CREATED,
)
def change_status(
    employee_id: int,
    payload: StatusChangeRequest,
    current: CurrentUser = Depends(require_roles(*STATUS_ROLES)),
    session: Session = Depends(get_session),
):
    """Promote / demote / terminate / reactivate a staff member."""
    action = payload.action_type
    if action not in _NOTIFY_TYPE:
        raise HTTPException(status_code=422, detail="Unsupported status action.")

    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")

    details: dict = {}
    if payload.reason and payload.reason.strip():
        details["reason"] = payload.reason.strip()

    if action in ("PROMOTION", "DEMOTION"):
        if payload.to_position_id is None:
            raise HTTPException(status_code=422, detail="A target position is required.")
        pos = session.get(Positions, payload.to_position_id)
        if pos is None or pos.tenant_id != current.tenant_id:
            raise HTTPException(status_code=422, detail="Unknown position.")
        # New position must be in the employee's own brand (if the employee has one).
        emp_brand_id = None
        if emp.primary_store_id is not None:
            st = session.get(Stores, emp.primary_store_id)
            emp_brand_id = st.brand_id if st else None
        if emp_brand_id is not None and pos.brand_id != emp_brand_id:
            raise HTTPException(
                status_code=422,
                detail="That position belongs to a different brand.",
            )
        old_pos = (
            session.get(Positions, emp.position_id)
            if emp.position_id is not None
            else None
        )
        details.update(
            {
                "from_position_id": emp.position_id,
                "from_position_title": old_pos.position_title if old_pos else None,
                "to_position_id": pos.position_id,
                "to_position_title": pos.position_title,
            }
        )
        emp.position_id = pos.position_id
    elif action == "TERMINATION":
        if emp.employment_status == "terminated":
            raise HTTPException(
                status_code=400, detail="This staff member is already terminated."
            )
        emp.employment_status = "terminated"
    elif action == "REACTIVATION":
        if emp.employment_status != "terminated":
            raise HTTPException(
                status_code=400, detail="This staff member is already active."
            )
        emp.employment_status = "active"

    session.add(emp)
    session.commit()

    log = StaffStatusLog(
        employee_id=emp.employee_id,
        action_type=action,
        details=details,
        processed_by=current.user_id,
    )
    session.add(log)
    session.add(
        Notifications(
            tenant_id=current.tenant_id,
            recipient_role="IT",
            type=_NOTIFY_TYPE[action],
            payload={
                "employee_id": emp.employee_id,
                "employee_name": emp.employee_name,
                "action": action,
                "to_position_title": details.get("to_position_title"),
                "by_user_id": current.user_id,
                "by_username": current.username,
                "reason": details.get("reason"),
            },
        )
    )
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="employees",
            record_id=str(emp.employee_id),
            old_value=None,
            new_value={"status_change": action, **details},
        )
    )
    session.commit()
    session.refresh(log)
    return _to_item(log, emp.employee_name, current.username)


@router.get("/{employee_id}/status-log", response_model=list[StatusLogItem])
def status_log(
    employee_id: int,
    current: CurrentUser = Depends(require_roles(*STATUS_ROLES)),
    session: Session = Depends(get_session),
):
    """Full status-change history for one employee (includes transfers), newest first."""
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    logs = session.exec(
        select(StaffStatusLog)
        .where(StaffStatusLog.employee_id == employee_id)
        .order_by(StaffStatusLog.timestamp.desc())
    ).all()
    names = _user_names(session, {log.processed_by for log in logs})
    return [
        _to_item(log, emp.employee_name, names.get(log.processed_by, "Unknown"))
        for log in logs
    ]


@router.get("/status/feed", response_model=list[StatusLogItem])
def status_feed(
    current: CurrentUser = Depends(require_roles(*STATUS_ROLES)),
    session: Session = Depends(get_session),
):
    """Recent status changes across all staff, newest first (capped at 100)."""
    emp_names = {
        e.employee_id: e.employee_name
        for e in session.exec(
            select(Employees).where(Employees.tenant_id == current.tenant_id)
        ).all()
    }
    logs = [
        log
        for log in session.exec(
            select(StaffStatusLog).order_by(StaffStatusLog.timestamp.desc())
        ).all()
        if log.employee_id in emp_names
    ][:100]
    names = _user_names(session, {log.processed_by for log in logs})
    return [
        _to_item(
            log,
            emp_names.get(log.employee_id, "Unknown"),
            names.get(log.processed_by, "Unknown"),
        )
        for log in logs
    ]

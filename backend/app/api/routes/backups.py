"""Database backup management — Super Admin only (a dump contains all data).

Manual runs stream progress via the row's status (running -> completed | failed);
downloads are gated + audited; scheduling is stored in app_settings and applied
by the in-process scheduler.
"""
import os

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core import backup as backup_svc
from app.core import scheduler
from app.core.app_settings import get_setting, set_setting
from app.core.database import get_session
from app.models.models import AuditLogs, Backups
from app.schemas.auth import CurrentUser
from app.schemas.backup import BackupRead, ScheduleRead, ScheduleUpdate

router = APIRouter(prefix="/api/v1/backups", tags=["backups"])

# A dump is the whole database — Super Admin only.
SUPER = ("Super Admin",)
_TENANT = 1
_SCHEDULES = {"off", "daily", "weekly"}


def _read(b: Backups) -> BackupRead:
    return BackupRead(
        id=b.id,
        filename=b.filename,
        status=b.status,
        kind=b.kind,
        size_bytes=b.size_bytes,
        created_by=b.created_by,
        started_at=b.started_at,
        finished_at=b.finished_at,
        error=b.error,
    )


# ---- Schedule (declared before /{id} so "schedule" isn't parsed as an id) ----
@router.get("/schedule", response_model=ScheduleRead)
def get_schedule(
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    try:
        retention = int(get_setting(session, current.tenant_id, "backup_retention") or "10")
    except (TypeError, ValueError):
        retention = 10
    return ScheduleRead(
        schedule=get_setting(session, current.tenant_id, "backup_schedule") or "off",
        time=get_setting(session, current.tenant_id, "backup_time") or "02:00",
        retention=retention,
    )


@router.put("/schedule", response_model=ScheduleRead)
def set_schedule(
    payload: ScheduleUpdate,
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    sched = payload.schedule.lower().strip()
    if sched not in _SCHEDULES:
        raise HTTPException(status_code=422, detail="Schedule must be off, daily or weekly.")
    try:
        hh, mm = (int(x) for x in payload.time.split(":"))
        assert 0 <= hh < 24 and 0 <= mm < 60
    except (ValueError, AssertionError):
        raise HTTPException(status_code=422, detail="Time must be HH:MM (24h).")
    retention = max(1, min(100, payload.retention))

    set_setting(session, current.tenant_id, "backup_schedule", sched)
    set_setting(session, current.tenant_id, "backup_time", f"{hh:02d}:{mm:02d}")
    set_setting(session, current.tenant_id, "backup_retention", str(retention))
    session.commit()
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="app_settings",
            record_id="backup_schedule",
            old_value=None,
            new_value={"schedule": sched, "time": f"{hh:02d}:{mm:02d}", "retention": retention},
        )
    )
    session.commit()
    scheduler.reschedule()
    return ScheduleRead(schedule=sched, time=f"{hh:02d}:{mm:02d}", retention=retention)


# ---- Backups -----------------------------------------------------------------
@router.get("", response_model=list[BackupRead])
def list_backups(
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(Backups)
        .where(Backups.tenant_id == current.tenant_id)
        .order_by(Backups.started_at.desc())
    ).all()
    return [_read(b) for b in rows]


@router.post("", response_model=BackupRead, status_code=status.HTTP_201_CREATED)
def create_backup(
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    row = backup_svc.start_backup(session, current.tenant_id, "manual", current.user_id)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="backups",
            record_id=str(row.id),
            old_value=None,
            new_value={"filename": row.filename, "kind": "manual"},
        )
    )
    session.commit()
    return _read(row)


@router.get("/{backup_id}", response_model=BackupRead)
def get_backup(
    backup_id: int,
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    b = session.get(Backups, backup_id)
    if b is None or b.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Backup not found.")
    return _read(b)


@router.get("/{backup_id}/download")
def download_backup(
    backup_id: int,
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    b = session.get(Backups, backup_id)
    if b is None or b.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Backup not found.")
    if b.status != "completed":
        raise HTTPException(status_code=409, detail="Backup is not ready.")
    path = os.path.join(backup_svc.BACKUP_DIR, b.filename)
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="Backup file is missing.")
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="backups",
            record_id=str(b.id),
            old_value=None,
            new_value={"downloaded": b.filename},
        )
    )
    session.commit()
    return FileResponse(path, media_type="application/sql", filename=b.filename)


@router.delete("/{backup_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_backup(
    backup_id: int,
    current: CurrentUser = Depends(require_roles(*SUPER)),
    session: Session = Depends(get_session),
):
    b = session.get(Backups, backup_id)
    if b is None or b.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Backup not found.")
    path = os.path.join(backup_svc.BACKUP_DIR, b.filename)
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        pass
    snap = {"filename": b.filename}
    session.delete(b)
    session.commit()
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table="backups",
            record_id=str(backup_id),
            old_value=snap,
            new_value=None,
        )
    )
    session.commit()
    return None

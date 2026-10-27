"""Attendance register (weekly, per store) — formatted like the paper register.

Combines the scheduled shift ("Roster") with the actual clock in/out from the
clock-in system, and computes Hours. Scoped to the Non-Oracle roster (the staff
who clock in). Roster cells are editable (simple scheduling).
"""

from datetime import date, datetime, time, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.api.routes.clock import MANAGER_PUNCH_ROLES, _manager_store_ids
from app.api.routes.non_oracle import employee_is_non_oracle
from app.core.database import get_session
from app.models.models import ClockEvents, Employees, Shifts, Stores
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/attendance", tags=["attendance"])

# Trinidad is UTC-4 year-round (no DST). Clock events are stored as naive UTC;
# display them in local time.
_LOCAL = timezone(timedelta(hours=-4))
_WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


class StoreOption(BaseModel):
    store_id: int
    store_name: str


class DayCell(BaseModel):
    date: str  # YYYY-MM-DD
    weekday: str
    roster: Optional[str] = None
    in_time: Optional[str] = None
    out_time: Optional[str] = None
    hours: Optional[str] = None  # "H:MM"


class EmployeeRow(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    days: list[DayCell]
    total_hours: str


class Register(BaseModel):
    store_id: int
    store_name: str
    week_start: str
    week_end: str
    employees: list[EmployeeRow]


class ShiftUpdate(BaseModel):
    employee_id: int
    work_date: date
    roster: str  # blank clears the cell


def _monday_of(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _local(dt: datetime) -> datetime:
    """Interpret a naive-UTC timestamp as local (AST)."""
    return dt.replace(tzinfo=timezone.utc).astimezone(_LOCAL)


def _fmt_time(dt: datetime) -> str:
    local = _local(dt)
    h = local.hour % 12 or 12
    ap = "AM" if local.hour < 12 else "PM"
    return f"{h}:{local.minute:02d} {ap}"


def _fmt_hm(minutes: int) -> str:
    return f"{minutes // 60}:{minutes % 60:02d}"


def _store_scope(session: Session, current: CurrentUser, store_id: int) -> Stores:
    store = session.get(Stores, store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Store not found.")
    scope = _manager_store_ids(session, current)
    if scope is not None and store_id not in scope:
        raise HTTPException(status_code=403, detail="Not your store.")
    return store


@router.get("/stores", response_model=list[StoreOption])
def stores_for_attendance(
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """Stores the current user may view the register for."""
    scope = _manager_store_ids(session, current)  # None = all
    rows = session.exec(
        select(Stores)
        .where(Stores.tenant_id == current.tenant_id)
        .order_by(Stores.store_name)
    ).all()
    return [
        StoreOption(store_id=s.store_id, store_name=s.store_name)
        for s in rows
        if scope is None or s.store_id in scope
    ]


@router.get("/register", response_model=Register)
def register(
    store_id: int,
    week_start: Optional[date] = None,
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """The weekly attendance register for a store (Monday–Sunday)."""
    store = _store_scope(session, current, store_id)
    monday = _monday_of(week_start or date.today())
    days = [monday + timedelta(days=i) for i in range(7)]
    week_end = days[-1]

    # Non-Oracle employees whose primary store is this one.
    employees = [
        e
        for e in session.exec(
            select(Employees)
            .where(
                Employees.tenant_id == current.tenant_id,
                Employees.primary_store_id == store_id,
            )
            .order_by(Employees.employee_name)
        ).all()
        if employee_is_non_oracle(session, e)
    ]
    emp_ids = [e.employee_id for e in employees]

    # Shifts (roster) for the week, keyed by (employee_id, date).
    roster: dict[tuple[int, date], str] = {}
    if emp_ids:
        for s in session.exec(
            select(Shifts).where(
                Shifts.employee_id.in_(emp_ids),
                Shifts.work_date >= monday,
                Shifts.work_date <= week_end,
            )
        ).all():
            roster[(s.employee_id, s.work_date)] = s.roster

    # Clock events for the week (local-day bucketed), keyed by (employee_id, date).
    start_utc = datetime.combine(monday, time.min).replace(tzinfo=_LOCAL).astimezone(
        timezone.utc
    ).replace(tzinfo=None)
    end_utc = datetime.combine(week_end + timedelta(days=1), time.min).replace(
        tzinfo=_LOCAL
    ).astimezone(timezone.utc).replace(tzinfo=None)
    ins: dict[tuple[int, date], datetime] = {}
    outs: dict[tuple[int, date], datetime] = {}
    if emp_ids:
        for ev in session.exec(
            select(ClockEvents)
            .where(
                ClockEvents.employee_id.in_(emp_ids),
                ClockEvents.occurred_at >= start_utc,
                ClockEvents.occurred_at < end_utc,
            )
            .order_by(ClockEvents.occurred_at)
        ).all():
            d = _local(ev.occurred_at).date()
            key = (ev.employee_id, d)
            if ev.event_type == "in":
                ins.setdefault(key, ev.occurred_at)  # first IN of the day
            elif ev.event_type == "out":
                outs[key] = ev.occurred_at  # last OUT of the day

    rows: list[EmployeeRow] = []
    for e in employees:
        cells: list[DayCell] = []
        total_min = 0
        for i, d in enumerate(days):
            key = (e.employee_id, d)
            in_dt = ins.get(key)
            out_dt = outs.get(key)
            hours = None
            if in_dt and out_dt and out_dt > in_dt:
                mins = int((out_dt - in_dt).total_seconds() // 60)
                total_min += mins
                hours = _fmt_hm(mins)
            cells.append(
                DayCell(
                    date=d.isoformat(),
                    weekday=_WEEKDAYS[i],
                    roster=roster.get(key),
                    in_time=_fmt_time(in_dt) if in_dt else None,
                    out_time=_fmt_time(out_dt) if out_dt else None,
                    hours=hours,
                )
            )
        rows.append(
            EmployeeRow(
                employee_id=e.employee_id,
                employee_name=e.employee_name,
                payroll_id=e.payroll_id,
                days=cells,
                total_hours=_fmt_hm(total_min),
            )
        )

    return Register(
        store_id=store_id,
        store_name=store.store_name,
        week_start=monday.isoformat(),
        week_end=week_end.isoformat(),
        employees=rows,
    )


@router.put("/shift")
def set_shift(
    payload: ShiftUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """Set (or clear, with a blank value) an employee's roster for a date."""
    emp = session.get(Employees, payload.employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    if emp.primary_store_id is not None:
        _store_scope(session, current, emp.primary_store_id)
    existing = session.exec(
        select(Shifts).where(
            Shifts.employee_id == payload.employee_id,
            Shifts.work_date == payload.work_date,
        )
    ).first()
    value = payload.roster.strip()
    if not value:
        if existing is not None:
            session.delete(existing)
            session.commit()
        return {"detail": "cleared"}
    if existing is None:
        existing = Shifts(
            tenant_id=current.tenant_id,
            employee_id=payload.employee_id,
            work_date=payload.work_date,
            roster=value,
            created_by=current.user_id,
        )
    else:
        existing.roster = value
        existing.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    session.add(existing)
    session.commit()
    return {"detail": "saved"}

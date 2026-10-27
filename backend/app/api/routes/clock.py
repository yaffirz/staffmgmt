"""Clock-in system.

- Kiosk (no login): identify by fingerprint template and punch in/out. In dev
  mode an operator may pick an employee to simulate a scan (no reader needed).
- Manager-assisted (login): a store manager clocks an employee in/out on their
  behalf when the employee can't scan.
- Events: a basic feed/timesheet for admins & managers.

Scoped to the Non-Oracle roster for now.
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

import json

from app.api.deps import get_current_user, require_roles
from app.api.routes.employees import _effective_brand_id
from app.api.routes.non_oracle import employee_is_non_oracle
from app.core import matcher
from app.core.app_settings import get_bool
from app.core.config import settings as app_config
from app.core.database import get_session
from app.models.models import (
    AreaManagerBrands,
    AreaManagers,
    Brands,
    ClockEvents,
    Employees,
    Fingerprints,
    StoreUsers,
    Stores,
)
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/clock", tags=["clock"])

# Who may clock an employee in/out on their behalf (manager-assisted).
MANAGER_PUNCH_ROLES = (
    "Super Admin",
    "Admin",
    "IT",
    "Area Manager",
    "Store",
    "Foodmall",
)


def _naive_utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _tenant() -> int:
    return app_config.DEFAULT_TENANT_ID


class ClockConfig(BaseModel):
    enabled: bool
    dev_mode: bool


class IdentifyRequest(BaseModel):
    template: Optional[str] = None
    employee_id: Optional[int] = None  # dev-mode simulate only


class PunchRequest(BaseModel):
    template: Optional[str] = None
    employee_id: Optional[int] = None  # dev-mode simulate only
    note: Optional[str] = None


class ManagerPunchRequest(BaseModel):
    employee_id: int
    event_type: Optional[str] = None  # explicit 'in'/'out', else auto-toggle
    note: Optional[str] = None


class EmployeeStatus(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    brand_name: Optional[str] = None
    store_name: Optional[str] = None
    last_event_type: Optional[str] = None
    last_event_at: Optional[datetime] = None
    next_event_type: str  # 'in' | 'out'


class ClockEventRead(BaseModel):
    clock_event_id: int
    employee_id: int
    employee_name: str
    event_type: str
    occurred_at: datetime
    source: str
    note: Optional[str] = None


class RosterEntry(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    brand_name: Optional[str] = None
    store_name: Optional[str] = None


class PunchResult(BaseModel):
    event: ClockEventRead
    status: EmployeeStatus


def _names(session: Session, emp: Employees) -> tuple[Optional[str], Optional[str]]:
    store = (
        session.get(Stores, emp.primary_store_id)
        if emp.primary_store_id is not None
        else None
    )
    brand_id = _effective_brand_id(emp, store)
    brand = session.get(Brands, brand_id) if brand_id is not None else None
    return (brand.brand_name if brand else None, store.store_name if store else None)


def _last_event(session: Session, employee_id: int) -> Optional[ClockEvents]:
    return session.exec(
        select(ClockEvents)
        .where(ClockEvents.employee_id == employee_id)
        .order_by(ClockEvents.occurred_at.desc(), ClockEvents.clock_event_id.desc())
    ).first()


def _next_type(last: Optional[ClockEvents]) -> str:
    return "out" if (last is not None and last.event_type == "in") else "in"


def _status(session: Session, emp: Employees) -> EmployeeStatus:
    brand_name, store_name = _names(session, emp)
    last = _last_event(session, emp.employee_id)
    return EmployeeStatus(
        employee_id=emp.employee_id,
        employee_name=emp.employee_name,
        payroll_id=emp.payroll_id,
        brand_name=brand_name,
        store_name=store_name,
        last_event_type=last.event_type if last else None,
        last_event_at=last.occurred_at if last else None,
        next_event_type=_next_type(last),
    )


def _require_enabled(session: Session) -> None:
    if not get_bool(session, _tenant(), "clock_in_enabled", default=True):
        raise HTTPException(status_code=403, detail="Clock-in is turned off.")


def _resolve_kiosk_employee(
    session: Session, tenant: int, template: Optional[str], employee_id: Optional[int]
) -> Employees:
    """Resolve the employee for a kiosk identify/punch. A fingerprint template
    match is the real path; an employee_id is accepted only when dev mode is on."""
    dev = get_bool(session, tenant, "clock_dev_mode", default=False)
    emp: Optional[Employees] = None
    if template:
        fp = session.exec(
            select(Fingerprints).where(
                Fingerprints.tenant_id == tenant, Fingerprints.template == template
            )
        ).first()
        if fp is not None:
            emp = session.get(Employees, fp.employee_id)
    elif employee_id is not None:
        if not dev:
            raise HTTPException(
                status_code=403,
                detail="Simulated scans are disabled. Scan a fingerprint.",
            )
        emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Fingerprint not recognised.")
    if not employee_is_non_oracle(session, emp):
        raise HTTPException(
            status_code=400, detail="This employee is not on the clock-in roster."
        )
    return emp


def _record(
    session: Session,
    emp: Employees,
    source: str,
    *,
    event_type: Optional[str] = None,
    recorded_by: Optional[int] = None,
    note: Optional[str] = None,
) -> ClockEvents:
    etype = event_type or _next_type(_last_event(session, emp.employee_id))
    if etype not in ("in", "out"):
        raise HTTPException(status_code=422, detail="event_type must be 'in' or 'out'.")
    ev = ClockEvents(
        tenant_id=emp.tenant_id,
        employee_id=emp.employee_id,
        event_type=etype,
        occurred_at=_naive_utcnow(),
        source=source,
        recorded_by=recorded_by,
        note=note,
    )
    session.add(ev)
    session.commit()
    session.refresh(ev)
    return ev


def _event_read(ev: ClockEvents, emp: Employees) -> ClockEventRead:
    return ClockEventRead(
        clock_event_id=ev.clock_event_id,
        employee_id=ev.employee_id,
        employee_name=emp.employee_name,
        event_type=ev.event_type,
        occurred_at=ev.occurred_at,
        source=ev.source,
        note=ev.note,
    )


# ---- Kiosk (no login) ----

@router.get("/config", response_model=ClockConfig)
def kiosk_config(session: Session = Depends(get_session)):
    """Public: whether the kiosk is enabled and whether dev simulate is on."""
    t = _tenant()
    return ClockConfig(
        enabled=get_bool(session, t, "clock_in_enabled", default=True),
        dev_mode=get_bool(session, t, "clock_dev_mode", default=False),
    )


@router.get("/roster", response_model=list[RosterEntry])
def kiosk_roster(session: Session = Depends(get_session)):
    """Public, DEV ONLY: the non-Oracle roster for the simulate-scan picker.
    Returns empty unless clock_dev_mode is on, so no roster leaks in production."""
    _require_enabled(session)
    t = _tenant()
    if not get_bool(session, t, "clock_dev_mode", default=False):
        return []
    non_oracle_brands = {
        b.brand_id
        for b in session.exec(
            select(Brands).where(
                Brands.tenant_id == t, Brands.non_oracle == True  # noqa: E712
            )
        ).all()
    }
    stores = {
        s.store_id: s
        for s in session.exec(select(Stores).where(Stores.tenant_id == t)).all()
    }
    brands = {
        b.brand_id: b
        for b in session.exec(select(Brands).where(Brands.tenant_id == t)).all()
    }
    out: list[RosterEntry] = []
    for emp in session.exec(
        select(Employees)
        .where(Employees.tenant_id == t)
        .order_by(Employees.employee_name)
    ).all():
        store = stores.get(emp.primary_store_id)
        if emp.non_oracle_override is not None:
            member = emp.non_oracle_override
        else:
            eff = _effective_brand_id(emp, store)
            member = eff is not None and eff in non_oracle_brands
        if not member:
            continue
        eff = _effective_brand_id(emp, store)
        brand = brands.get(eff) if eff is not None else None
        out.append(
            RosterEntry(
                employee_id=emp.employee_id,
                employee_name=emp.employee_name,
                payroll_id=emp.payroll_id,
                brand_name=brand.brand_name if brand else None,
                store_name=store.store_name if store else None,
            )
        )
    return out


@router.post("/identify", response_model=EmployeeStatus)
def identify(payload: IdentifyRequest, session: Session = Depends(get_session)):
    """Public: resolve who a scan belongs to and whether they'd clock in or out."""
    _require_enabled(session)
    emp = _resolve_kiosk_employee(
        session, _tenant(), payload.template, payload.employee_id
    )
    return _status(session, emp)


@router.post("/punch", response_model=PunchResult)
def punch(payload: PunchRequest, session: Session = Depends(get_session)):
    """Public: record the next in/out punch for the scanned employee."""
    _require_enabled(session)
    emp = _resolve_kiosk_employee(
        session, _tenant(), payload.template, payload.employee_id
    )
    source = "kiosk" if payload.template else "dev"
    ev = _record(session, emp, source, note=payload.note)
    return PunchResult(event=_event_read(ev, emp), status=_status(session, emp))


# ---- Kiosk fingerprint scan → identify (1:N via the matcher) ----

class ScanRequest(BaseModel):
    sample: str  # a freshly captured PNG (base64) — the probe
    note: Optional[str] = None


def _identify_by_scan(session: Session, tenant: int, sample: str) -> Employees:
    """Match a captured scan against ALL enrolled non-Oracle fingerprints and
    return the employee it belongs to, or 404 if no confident match."""
    if not (sample or "").strip():
        raise HTTPException(status_code=422, detail="A scan is required.")
    candidates: list[str] = []
    emp_by_candidate: list[int] = []
    for fp in session.exec(
        select(Fingerprints).where(Fingerprints.tenant_id == tenant)
    ).all():
        try:
            parsed = json.loads(fp.template)
        except (ValueError, TypeError):
            continue  # dev placeholder
        if not isinstance(parsed, dict):
            continue
        for s in parsed.get("samples", []) or []:
            if isinstance(s, str) and s:
                candidates.append(s)
                emp_by_candidate.append(fp.employee_id)
    if not candidates:
        raise HTTPException(status_code=404, detail="No fingerprints are enrolled yet.")
    try:
        res = matcher.verify(sample, candidates)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Matcher unavailable: {exc}") from exc
    best = res.get("bestIndex", -1)
    if not res.get("match") or not (isinstance(best, int) and 0 <= best < len(emp_by_candidate)):
        raise HTTPException(status_code=404, detail="Fingerprint not recognised.")
    emp = session.get(Employees, emp_by_candidate[best])
    if emp is None or emp.tenant_id != tenant or not employee_is_non_oracle(session, emp):
        raise HTTPException(status_code=404, detail="Fingerprint not recognised.")
    return emp


@router.post("/identify-scan", response_model=EmployeeStatus)
def identify_scan(payload: ScanRequest, session: Session = Depends(get_session)):
    """Public: identify who a fingerprint scan belongs to (no punch yet)."""
    _require_enabled(session)
    emp = _identify_by_scan(session, _tenant(), payload.sample)
    return _status(session, emp)


@router.post("/punch-scan", response_model=PunchResult)
def punch_scan(payload: ScanRequest, session: Session = Depends(get_session)):
    """Public: identify a fingerprint scan and record the next in/out punch."""
    _require_enabled(session)
    emp = _identify_by_scan(session, _tenant(), payload.sample)
    ev = _record(session, emp, "kiosk", note=payload.note)
    return PunchResult(event=_event_read(ev, emp), status=_status(session, emp))


# ---- Manager-assisted (login) ----

_ADMIN_ROLES = {"Super Admin", "Admin", "IT"}


def _manager_store_ids(session: Session, current: CurrentUser):
    """Store ids a manager may clock staff in, or None for all (admin roles).
    Store/Foodmall → their store; Area Manager → stores in their brands."""
    if _ADMIN_ROLES & set(current.roles or [current.role]):
        return None
    store_ids: set[int] = set()
    for su in session.exec(
        select(StoreUsers).where(StoreUsers.user_id == current.user_id)
    ).all():
        store_ids.add(su.store_id)
    mgr = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == current.user_id)
    ).first()
    if mgr is not None:
        brand_ids = {
            b.brand_id
            for b in session.exec(
                select(AreaManagerBrands).where(
                    AreaManagerBrands.manager_id == mgr.manager_id
                )
            ).all()
        }
        if brand_ids:
            for s in session.exec(
                select(Stores).where(
                    Stores.tenant_id == current.tenant_id,
                    Stores.brand_id.in_(brand_ids),
                )
            ).all():
                store_ids.add(s.store_id)
    return store_ids


@router.get("/my-roster", response_model=list[EmployeeStatus])
def my_roster(
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """Non-Oracle employees this manager may clock in/out, with current status.
    Scoped by role: admins see all; store/area managers see their stores."""
    tenant = current.tenant_id
    scope = _manager_store_ids(session, current)  # None = all
    non_oracle_brands = {
        b.brand_id
        for b in session.exec(
            select(Brands).where(
                Brands.tenant_id == tenant, Brands.non_oracle == True  # noqa: E712
            )
        ).all()
    }
    stores = {
        s.store_id: s
        for s in session.exec(select(Stores).where(Stores.tenant_id == tenant)).all()
    }
    members: list[Employees] = []
    for emp in session.exec(
        select(Employees)
        .where(Employees.tenant_id == tenant)
        .order_by(Employees.employee_name)
    ).all():
        if scope is not None and emp.primary_store_id not in scope:
            continue
        store = stores.get(emp.primary_store_id)
        if emp.non_oracle_override is not None:
            member = emp.non_oracle_override
        else:
            eff = _effective_brand_id(emp, store)
            member = eff is not None and eff in non_oracle_brands
        if member:
            members.append(emp)

    # Batch the latest event per employee (first seen = newest).
    last_by_emp: dict[int, ClockEvents] = {}
    emp_ids = [e.employee_id for e in members]
    if emp_ids:
        for ev in session.exec(
            select(ClockEvents)
            .where(ClockEvents.employee_id.in_(emp_ids))
            .order_by(
                ClockEvents.occurred_at.desc(), ClockEvents.clock_event_id.desc()
            )
        ).all():
            last_by_emp.setdefault(ev.employee_id, ev)

    out: list[EmployeeStatus] = []
    for emp in members:
        store = stores.get(emp.primary_store_id)
        brand_id = _effective_brand_id(emp, store)
        brand = session.get(Brands, brand_id) if brand_id is not None else None
        last = last_by_emp.get(emp.employee_id)
        out.append(
            EmployeeStatus(
                employee_id=emp.employee_id,
                employee_name=emp.employee_name,
                payroll_id=emp.payroll_id,
                brand_name=brand.brand_name if brand else None,
                store_name=store.store_name if store else None,
                last_event_type=last.event_type if last else None,
                last_event_at=last.occurred_at if last else None,
                next_event_type=_next_type(last),
            )
        )
    return out


@router.post("/manager-punch", response_model=PunchResult)
def manager_punch(
    payload: ManagerPunchRequest,
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """A manager clocks an employee in/out on their behalf."""
    _require_enabled(session)
    emp = session.get(Employees, payload.employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    if not employee_is_non_oracle(session, emp):
        raise HTTPException(
            status_code=400, detail="This employee is not on the clock-in roster."
        )
    ev = _record(
        session,
        emp,
        "manager",
        event_type=payload.event_type,
        recorded_by=current.user_id,
        note=payload.note,
    )
    return PunchResult(event=_event_read(ev, emp), status=_status(session, emp))


# ---- Events / basic timesheet (login) ----

@router.get("/events", response_model=list[ClockEventRead])
def list_events(
    employee_id: Optional[int] = None,
    limit: int = 200,
    current: CurrentUser = Depends(require_roles(*MANAGER_PUNCH_ROLES)),
    session: Session = Depends(get_session),
):
    """Recent clock events (newest first), optionally for one employee."""
    limit = max(1, min(limit, 1000))
    q = select(ClockEvents).where(ClockEvents.tenant_id == current.tenant_id)
    if employee_id is not None:
        q = q.where(ClockEvents.employee_id == employee_id)
    q = q.order_by(
        ClockEvents.occurred_at.desc(), ClockEvents.clock_event_id.desc()
    ).limit(limit)
    events = session.exec(q).all()
    names = {
        e.employee_id: e.employee_name
        for e in session.exec(
            select(Employees).where(Employees.tenant_id == current.tenant_id)
        ).all()
    }
    return [
        ClockEventRead(
            clock_event_id=ev.clock_event_id,
            employee_id=ev.employee_id,
            employee_name=names.get(ev.employee_id, f"#{ev.employee_id}"),
            event_type=ev.event_type,
            occurred_at=ev.occurred_at,
            source=ev.source,
            note=ev.note,
        )
        for ev in events
    ]

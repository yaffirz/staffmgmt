"""External platforms + the Area Manager dashboard.

Track which 3rd-party platforms (e.g. Taqtics, Oracle) each employee has access
to — shown as a coloured tag next to the staffer. Managed by Admin / IT / HR /
Area Manager (AMs scoped to their own cluster). The dashboard shows an area's
stores -> staff -> positions -> platform tags.
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.core.scoping import dashboard_scope, effective_brand_id, stores_in_brands
from app.models.models import (
    Brands,
    EmployeeAdditionalStores,
    EmployeePlatforms,
    Employees,
    ExternalPlatforms,
    Positions,
    Stores,
)
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1", tags=["platforms"])

# Who may view/edit the dashboard. Ops Managers + Area Managers are scoped to
# their own brands/cluster by `dashboard_scope`; the admin roles see all.
MANAGE_ROLES = (
    "Super Admin",
    "Admin",
    "IT",
    "HR",
    "Ops Manager",
    "Area Manager",
)


# ---------- schemas ----------
class PlatformRead(BaseModel):
    platform_id: int
    name: str
    color: Optional[str] = None


class PlatformCreate(BaseModel):
    name: str
    color: Optional[str] = None


class PlatformUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None


class EmpPlatform(BaseModel):
    platform_id: int
    name: str
    color: Optional[str] = None
    note: Optional[str] = None


class AssignItem(BaseModel):
    platform_id: int
    note: Optional[str] = None


class AssignRequest(BaseModel):
    items: list[AssignItem]


class DashStaff(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    position_title: Optional[str] = None
    platforms: list[EmpPlatform] = []


class DashStore(BaseModel):
    store_id: int
    store_name: str
    staff: list[DashStaff]


class DashBrand(BaseModel):
    brand_id: int
    brand_name: str


class Dashboard(BaseModel):
    brands: list[DashBrand]
    brand_id: Optional[int] = None
    brand_name: Optional[str] = None
    stores: list[DashStore]
    platform_catalog: list[PlatformRead]
    can_edit: bool


# ---------- helpers ----------
def _emp_platforms_map(session: Session, emp_ids: list[int]) -> dict[int, list[EmpPlatform]]:
    """Platform tags per employee, resolved with names/colours."""
    out: dict[int, list[EmpPlatform]] = {}
    if not emp_ids:
        return out
    cat = {
        p.platform_id: p
        for p in session.exec(select(ExternalPlatforms)).all()
    }
    for link in session.exec(
        select(EmployeePlatforms).where(EmployeePlatforms.employee_id.in_(emp_ids))
    ).all():
        p = cat.get(link.platform_id)
        if p is None:
            continue
        out.setdefault(link.employee_id, []).append(
            EmpPlatform(platform_id=p.platform_id, name=p.name, color=p.color, note=link.note)
        )
    for v in out.values():
        v.sort(key=lambda e: e.name.lower())
    return out


# ---------- platform catalog ----------
@router.get("/platforms", response_model=list[PlatformRead])
def list_platforms(
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(ExternalPlatforms)
        .where(ExternalPlatforms.tenant_id == current.tenant_id)
        .order_by(ExternalPlatforms.name)
    ).all()
    return [PlatformRead(platform_id=p.platform_id, name=p.name, color=p.color) for p in rows]


@router.post("/platforms", response_model=PlatformRead, status_code=201)
def create_platform(
    payload: PlatformCreate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Name is required.")
    dup = session.exec(
        select(ExternalPlatforms).where(
            ExternalPlatforms.tenant_id == current.tenant_id,
            ExternalPlatforms.name == name,
        )
    ).first()
    if dup is not None:
        raise HTTPException(status_code=409, detail="A platform with that name exists.")
    row = ExternalPlatforms(tenant_id=current.tenant_id, name=name, color=(payload.color or None))
    session.add(row)
    session.commit()
    session.refresh(row)
    return PlatformRead(platform_id=row.platform_id, name=row.name, color=row.color)


@router.patch("/platforms/{platform_id}", response_model=PlatformRead)
def update_platform(
    platform_id: int,
    payload: PlatformUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    row = session.get(ExternalPlatforms, platform_id)
    if row is None or row.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Platform not found.")
    if payload.name is not None:
        row.name = payload.name.strip() or row.name
    if payload.color is not None:
        row.color = payload.color or None
    session.add(row)
    session.commit()
    session.refresh(row)
    return PlatformRead(platform_id=row.platform_id, name=row.name, color=row.color)


@router.delete("/platforms/{platform_id}", status_code=204)
def delete_platform(
    platform_id: int,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    row = session.get(ExternalPlatforms, platform_id)
    if row is None or row.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Platform not found.")
    for link in session.exec(
        select(EmployeePlatforms).where(EmployeePlatforms.platform_id == platform_id)
    ).all():
        session.delete(link)
    session.delete(row)
    session.commit()


# ---------- per-employee access ----------
def _assert_can_edit_employee(session: Session, current: CurrentUser, emp: Employees) -> None:
    _brands, store_ids = dashboard_scope(session, current)
    if store_ids is None:
        return  # admin roles may edit anyone
    # Ops / Area Manager: the employee must be in one of their stores (primary
    # or additional).
    if emp.primary_store_id in store_ids:
        return
    extra = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id == emp.employee_id
        )
    ).all()
    if any(a.store_id in store_ids for a in extra):
        return
    raise HTTPException(status_code=403, detail="That employee is not in your area.")


@router.put("/employees/{employee_id}/platforms", response_model=list[EmpPlatform])
def set_employee_platforms(
    employee_id: int,
    payload: AssignRequest,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    _assert_can_edit_employee(session, current, emp)
    valid = {
        p.platform_id
        for p in session.exec(
            select(ExternalPlatforms).where(ExternalPlatforms.tenant_id == current.tenant_id)
        ).all()
    }
    wanted = {it.platform_id: (it.note or None) for it in payload.items if it.platform_id in valid}
    # Replace the set: delete, flush, then insert (avoids the unique-constraint
    # ordering bug — see CLAUDE.md).
    for link in session.exec(
        select(EmployeePlatforms).where(EmployeePlatforms.employee_id == employee_id)
    ).all():
        session.delete(link)
    session.flush()
    for pid, note in wanted.items():
        session.add(
            EmployeePlatforms(
                tenant_id=current.tenant_id,
                employee_id=employee_id,
                platform_id=pid,
                note=note,
                created_by=current.user_id,
            )
        )
    session.commit()
    return _emp_platforms_map(session, [employee_id]).get(employee_id, [])


# ---------- area dashboard ----------
@router.get("/area-dashboard", response_model=Dashboard)
def area_dashboard(
    brand_id: Optional[int] = None,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """An area's stores -> staff (positions) -> platform tags. Ops Managers are
    scoped to their brands, Area Managers to their store cluster; admin roles see
    everything."""
    tenant = current.tenant_id
    scope_brands, scope_stores = dashboard_scope(session, current)  # None = all
    all_brands = session.exec(
        select(Brands).where(Brands.tenant_id == tenant).order_by(Brands.brand_name)
    ).all()
    visible = [
        b for b in all_brands if scope_brands is None or b.brand_id in scope_brands
    ]
    brands_out = [DashBrand(brand_id=b.brand_id, brand_name=b.brand_name) for b in visible]

    selected = None
    if brand_id is not None:
        selected = next((b for b in visible if b.brand_id == brand_id), None)
    if selected is None and visible:
        selected = visible[0]

    stores_out: list[DashStore] = []
    if selected is not None:
        # Stores that SERVE the selected brand — a store's primary brand OR, for
        # a multi-brand foodmall, an extra brand it carries. So a foodmall
        # flagged Rituals that also carries Pizza Boys appears under both.
        serving_ids = stores_in_brands(session, tenant, {selected.brand_id})
        stores = session.exec(
            select(Stores)
            .where(Stores.tenant_id == tenant, Stores.store_id.in_(serving_ids))
            .order_by(Stores.store_name)
        ).all() if serving_ids else []
        # Area Managers only see their own cluster's stores within the brand.
        if scope_stores is not None:
            stores = [s for s in stores if s.store_id in scope_stores]
        store_by_id = {s.store_id: s for s in stores}
        positions = {
            p.position_id: p.position_title
            for p in session.exec(select(Positions).where(Positions.tenant_id == tenant)).all()
        }
        store_ids = [s.store_id for s in stores]
        emp_by_store: dict[int, list[Employees]] = {}
        if store_ids:
            for e in session.exec(
                select(Employees)
                .where(
                    Employees.tenant_id == tenant,
                    Employees.primary_store_id.in_(store_ids),
                    Employees.employment_status == "active",
                )
                .order_by(Employees.employee_name)
            ).all():
                # In a multi-brand foodmall, only count staff who belong to the
                # selected brand (explicit brand_id, else the store's brand).
                store = store_by_id.get(e.primary_store_id)
                if effective_brand_id(e, store) != selected.brand_id:
                    continue
                emp_by_store.setdefault(e.primary_store_id, []).append(e)
        all_emp_ids = [e.employee_id for lst in emp_by_store.values() for e in lst]
        plat = _emp_platforms_map(session, all_emp_ids)
        for s in stores:
            staff = [
                DashStaff(
                    employee_id=e.employee_id,
                    employee_name=e.employee_name,
                    payroll_id=e.payroll_id,
                    position_title=positions.get(e.position_id),
                    platforms=plat.get(e.employee_id, []),
                )
                for e in emp_by_store.get(s.store_id, [])
            ]
            stores_out.append(DashStore(store_id=s.store_id, store_name=s.store_name, staff=staff))

    catalog = [
        PlatformRead(platform_id=p.platform_id, name=p.name, color=p.color)
        for p in session.exec(
            select(ExternalPlatforms)
            .where(ExternalPlatforms.tenant_id == tenant)
            .order_by(ExternalPlatforms.name)
        ).all()
    ]
    return Dashboard(
        brands=brands_out,
        brand_id=selected.brand_id if selected else None,
        brand_name=selected.brand_name if selected else None,
        stores=stores_out,
        platform_catalog=catalog,
        can_edit=True,
    )

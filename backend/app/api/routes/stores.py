"""Store drilldown for admins/HR: the staff currently at a given store
(primary + additional-store coverage). Powers the notification deep-link
("show me where the staff was added").
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import (
    Brands,
    Employees,
    EmployeeAdditionalStores,
    Positions,
    Stores,
)
from app.schemas.auth import CurrentUser
from app.schemas.stores import StoreStaffMember, StoreStaffResponse

router = APIRouter(prefix="/api/v1/stores", tags=["stores"])

VIEW_ROLES = ("Super Admin", "Admin", "HR", "IT")


def _position_rank(title: str | None) -> int:
    t = (title or "").lower()
    if "manager" in t:
        return 0
    if "supervisor" in t:
        return 1
    return 2


@router.get("/{store_id}/staff", response_model=StoreStaffResponse)
def store_staff(
    store_id: int,
    current: CurrentUser = Depends(require_roles(*VIEW_ROLES)),
    session: Session = Depends(get_session),
):
    """All staff at a store: those whose primary store is here, plus those who
    cover it via an additional-store link (flagged `also_covers`)."""
    tenant = current.tenant_id
    store = session.get(Stores, store_id)
    if store is None or store.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Store not found.")
    brand = session.get(Brands, store.brand_id)

    positions = {
        p.position_id: p.position_title
        for p in session.exec(
            select(Positions).where(Positions.tenant_id == tenant)
        ).all()
    }

    # Primary-here staff.
    primary = session.exec(
        select(Employees).where(
            Employees.tenant_id == tenant,
            Employees.primary_store_id == store_id,
        )
    ).all()

    # Additional-store coverage (exclude those whose primary is already here).
    add_links = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.store_id == store_id
        )
    ).all()
    add_ids = {link.employee_id for link in add_links}
    add_emps = []
    if add_ids:
        add_emps = session.exec(
            select(Employees).where(
                Employees.tenant_id == tenant,
                Employees.employee_id.in_(add_ids),
            )
        ).all()

    entries: list[tuple[Employees, bool]] = [(e, False) for e in primary]
    for e in add_emps:
        if e.primary_store_id != store_id:
            entries.append((e, True))

    entries.sort(
        key=lambda pair: (
            _position_rank(positions.get(pair[0].position_id)),
            pair[0].employee_name.lower(),
        )
    )

    staff = [
        StoreStaffMember(
            employee_id=e.employee_id,
            employee_name=e.employee_name,
            payroll_id=e.payroll_id,
            position_title=positions.get(e.position_id),
            also_covers=cover,
        )
        for e, cover in entries
    ]

    return StoreStaffResponse(
        store_id=store.store_id,
        store_name=store.store_name,
        brand_id=store.brand_id,
        brand_name=brand.brand_name if brand else "",
        staff=staff,
    )

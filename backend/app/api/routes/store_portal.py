"""Store & Foodmall portal: a store-level login sees ONLY its own store's staff,
restricted to name + brand (no position, pay, contact, or other details). A
Foodmall store carries several brands, so its staff are grouped by brand.

Both roles can request a staffer be added to their store, which notifies Admins
(no direct change) — mirroring the Area Manager request flow in cluster.py.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import (
    AuditLogs,
    Brands,
    Employees,
    EmployeeAdditionalStores,
    Notifications,
    Positions,
    StoreBrands,
    Stores,
    StoreUsers,
)
from app.schemas.auth import CurrentUser
from app.schemas.store_portal import (
    StoreBrandGroup,
    StoreRequestStaff,
    StoreStaffLite,
    StoreSummary,
)

router = APIRouter(prefix="/api/v1/store", tags=["store-portal"])

STORE_ROLES = ("Store", "Foodmall")


def _resolve_store(current: CurrentUser, session: Session) -> Stores:
    """The single store this Store/Foodmall account is bound to (403 if none)."""
    link = session.exec(
        select(StoreUsers).where(StoreUsers.user_id == current.user_id)
    ).first()
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No store is linked to this account.",
        )
    store = session.get(Stores, link.store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Store not found.")
    return store


def _staff_at_store(session: Session, store: Stores) -> list[Employees]:
    """Staff whose primary store is here, plus those covering it via an
    additional-store link (deduped)."""
    tenant = store.tenant_id
    primary = session.exec(
        select(Employees).where(
            Employees.tenant_id == tenant,
            Employees.primary_store_id == store.store_id,
        )
    ).all()
    result = list(primary)
    seen = {e.employee_id for e in primary}
    add_ids = {
        link.employee_id
        for link in session.exec(
            select(EmployeeAdditionalStores).where(
                EmployeeAdditionalStores.store_id == store.store_id
            )
        ).all()
    }
    if add_ids:
        for e in session.exec(
            select(Employees).where(
                Employees.tenant_id == tenant,
                Employees.employee_id.in_(add_ids),
            )
        ).all():
            if e.employee_id not in seen:
                result.append(e)
                seen.add(e.employee_id)
    return result


@router.get("/summary", response_model=StoreSummary)
def store_summary(
    current: CurrentUser = Depends(require_roles(*STORE_ROLES)),
    session: Session = Depends(get_session),
):
    store = _resolve_store(current, session)
    extra = [
        sb.brand_id
        for sb in session.exec(
            select(StoreBrands).where(StoreBrands.store_id == store.store_id)
        ).all()
    ]
    effective = list(dict.fromkeys([store.brand_id, *extra]))
    brand_name = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == store.tenant_id)
        ).all()
    }
    pos_brand = {
        p.position_id: p.brand_id
        for p in session.exec(
            select(Positions).where(Positions.tenant_id == store.tenant_id)
        ).all()
    }

    groups_map: dict[int, list[StoreStaffLite]] = {bid: [] for bid in effective}
    for e in _staff_at_store(session, store):
        # A staffer's brand comes from their (brand-specific) position; fall back
        # to the store's primary brand.
        pb = pos_brand.get(e.position_id)
        bid = pb if pb in groups_map else store.brand_id
        groups_map[bid].append(
            StoreStaffLite(employee_id=e.employee_id, name=e.employee_name)
        )

    groups = [
        StoreBrandGroup(
            brand_id=bid,
            brand_name=brand_name.get(bid, ""),
            staff=sorted(groups_map[bid], key=lambda s: s.name.lower()),
        )
        for bid in effective
    ]
    return StoreSummary(
        store_id=store.store_id,
        store_name=store.store_name,
        is_foodmall=store.is_foodmall,
        groups=groups,
    )


@router.get("/employees/search", response_model=list[StoreStaffLite])
def search_staff(
    name: str = Query(..., min_length=1),
    current: CurrentUser = Depends(require_roles(*STORE_ROLES)),
    session: Session = Depends(get_session),
):
    """Find staff by name to request them into this store. Name only (no
    details), capped at 25."""
    q = name.strip().lower()
    if not q:
        return []
    emps = session.exec(
        select(Employees).where(Employees.tenant_id == current.tenant_id)
    ).all()
    return [
        StoreStaffLite(employee_id=e.employee_id, name=e.employee_name)
        for e in emps
        if q in e.employee_name.lower()
    ][:25]


@router.post("/request-staff", status_code=status.HTTP_201_CREATED)
def request_staff(
    payload: StoreRequestStaff,
    current: CurrentUser = Depends(require_roles(*STORE_ROLES)),
    session: Session = Depends(get_session),
):
    """Request a staffer be added to this store. Notifies Admins; makes no staff
    change (an admin fulfils it)."""
    store = _resolve_store(current, session)
    emp = session.get(Employees, payload.employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")

    notif = Notifications(
        tenant_id=current.tenant_id,
        recipient_role="Admin",
        type="STAFF_REQUESTED",
        payload={
            "employee_id": emp.employee_id,
            "employee_name": emp.employee_name,
            "requested_store_id": store.store_id,
            "requested_store_name": store.store_name,
            "by_user_id": current.user_id,
            "by_username": current.username,
        },
    )
    session.add(notif)
    session.commit()
    session.refresh(notif)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="notifications",
            record_id=str(notif.notification_id),
            old_value=None,
            new_value={
                "type": "STAFF_REQUESTED",
                "employee_id": emp.employee_id,
                "requested_store_id": store.store_id,
            },
        )
    )
    session.commit()
    return {"status": "requested", "notification_id": notif.notification_id}

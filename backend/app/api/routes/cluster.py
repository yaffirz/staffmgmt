"""Area Manager cluster: read view (Phase 2a) + Move/Request flows (Phase 2b).

An Area Manager's scope is BRAND-based: they cover one or more brands (via
`area_manager_brands`), and their cluster is every store in those brands.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.app_settings import get_bool
from app.core.database import get_session
from app.models.models import (
    AreaManagerBrands,
    AreaManagers,
    AuditLogs,
    Brands,
    Employees,
    EmployeeAdditionalStores,
    Notifications,
    Positions,
    StaffStatusLog,
    Stores,
)
from app.schemas.auth import CurrentUser
from app.schemas.cluster import (
    AssignStoreRequest,
    AssignStoreResult,
    ClusterResponse,
    ClusterStaff,
    ClusterStore,
    MoveRequest,
    MoveResult,
    RequestAssignmentRequest,
    RequestAssignmentResult,
    StaffSearchResult,
)

router = APIRouter(prefix="/api/v1/cluster", tags=["cluster"])

AM_ONLY = ("Area Manager",)
SEARCH_ROLES = ("Area Manager", "Admin", "Super Admin", "HR")


def _position_rank(title: str | None) -> int:
    """Order staff: managers first, then supervisors, then everyone else."""
    t = (title or "").lower()
    if "manager" in t:
        return 0
    if "supervisor" in t:
        return 1
    return 2


def _am_scope(current: CurrentUser, session: Session):
    """Resolve the calling AM's manager row, brand ids, and in-scope store ids.
    Raises 403 if the user has no area-manager profile."""
    manager = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == current.user_id)
    ).first()
    if manager is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No area-manager profile is linked to this account.",
        )
    brand_ids = {
        link.brand_id
        for link in session.exec(
            select(AreaManagerBrands).where(
                AreaManagerBrands.manager_id == manager.manager_id
            )
        ).all()
    }
    store_ids: set[int] = set()
    if brand_ids:
        store_ids = {
            s.store_id
            for s in session.exec(
                select(Stores).where(
                    Stores.tenant_id == current.tenant_id,
                    Stores.brand_id.in_(brand_ids),
                )
            ).all()
        }
    return manager, brand_ids, store_ids


@router.get("", response_model=ClusterResponse)
def get_cluster(
    current: CurrentUser = Depends(require_roles(*AM_ONLY)),
    session: Session = Depends(get_session),
):
    """Phase 2a read view: the AM's stores (brand-grouped) and their staff.
    A staffer here via an additional-store link is flagged `also_covers`."""
    _manager, _brand_ids, store_ids = _am_scope(current, session)
    if not store_ids:
        return ClusterResponse(stores=[])

    stores = session.exec(
        select(Stores).where(
            Stores.tenant_id == current.tenant_id, Stores.store_id.in_(store_ids)
        )
    ).all()
    brands = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    positions = {
        p.position_id: p.position_title
        for p in session.exec(
            select(Positions).where(Positions.tenant_id == current.tenant_id)
        ).all()
    }

    # Staff whose PRIMARY store is in scope.
    primary_emps = session.exec(
        select(Employees).where(
            Employees.tenant_id == current.tenant_id,
            Employees.primary_store_id.in_(store_ids),
        )
    ).all()
    # Staff linked to an in-scope store as an ADDITIONAL store.
    add_links = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.store_id.in_(store_ids)
        )
    ).all()
    add_emp_ids = {link.employee_id for link in add_links}
    add_emps = {}
    if add_emp_ids:
        add_emps = {
            e.employee_id: e
            for e in session.exec(
                select(Employees).where(
                    Employees.tenant_id == current.tenant_id,
                    Employees.employee_id.in_(add_emp_ids),
                )
            ).all()
        }

    # store_id -> list[(employee, also_covers)]
    by_store: dict[int, list[tuple[Employees, bool]]] = {sid: [] for sid in store_ids}
    for emp in primary_emps:
        by_store.setdefault(emp.primary_store_id, []).append((emp, False))
    for link in add_links:
        emp = add_emps.get(link.employee_id)
        if emp is None:
            continue
        # If this is also their primary store, they're already listed (not a cover).
        if emp.primary_store_id == link.store_id:
            continue
        by_store.setdefault(link.store_id, []).append((emp, True))

    result_stores: list[ClusterStore] = []
    for store in sorted(stores, key=lambda s: s.store_name):
        entries = by_store.get(store.store_id, [])
        entries.sort(
            key=lambda pair: (
                _position_rank(positions.get(pair[0].position_id)),
                pair[0].employee_name.lower(),
            )
        )
        staff = [
            ClusterStaff(
                employee_id=emp.employee_id,
                employee_name=emp.employee_name,
                position_title=positions.get(emp.position_id),
                also_covers=cover,
            )
            for emp, cover in entries
        ]
        result_stores.append(
            ClusterStore(
                store_id=store.store_id,
                store_name=store.store_name,
                brand_id=store.brand_id,
                brand_name=brands.get(store.brand_id, ""),
                staff=staff,
            )
        )
    return ClusterResponse(stores=result_stores)


@router.post("/employees/{employee_id}/move", response_model=MoveResult)
def move_staff(
    employee_id: int,
    payload: MoveRequest,
    current: CurrentUser = Depends(require_roles(*AM_ONLY)),
    session: Session = Depends(get_session),
):
    """Move a staffer's PRIMARY store to another store within the AM's cluster.
    Applies immediately; notifies Admins for visibility (not approval)."""
    if not get_bool(session, current.tenant_id, "area_managers_can_move", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Moving staff is currently disabled by an administrator.",
        )

    _manager, _brand_ids, store_ids = _am_scope(current, session)

    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")

    # Only staff whose PRIMARY store is in the AM's cluster are movable.
    if emp.primary_store_id not in store_ids:
        raise HTTPException(
            status_code=403,
            detail="This staff member's primary store is not in your cluster.",
        )

    to_store_id = payload.to_store_id
    if to_store_id == emp.primary_store_id:
        raise HTTPException(
            status_code=400, detail="Destination is the same as the current store."
        )
    if to_store_id not in store_ids:
        raise HTTPException(
            status_code=400, detail="Destination store is not in your cluster."
        )
    to_store = session.get(Stores, to_store_id)
    if to_store is None or to_store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=400, detail="Destination store not found.")

    from_store_id = emp.primary_store_id
    emp.primary_store_id = to_store_id
    session.add(emp)
    session.commit()

    session.add(
        StaffStatusLog(
            employee_id=emp.employee_id,
            action_type="TRANSFER",
            details={
                "from_store_id": from_store_id,
                "to_store_id": to_store_id,
                "by_user_id": current.user_id,
            },
            processed_by=current.user_id,
        )
    )
    session.add(
        Notifications(
            tenant_id=current.tenant_id,
            recipient_role="Admin",
            type="STAFF_MOVED",
            payload={
                "employee_id": emp.employee_id,
                "employee_name": emp.employee_name,
                "from_store_id": from_store_id,
                "to_store_id": to_store_id,
                "to_store_name": to_store.store_name,
                "by_user_id": current.user_id,
                "by_username": current.username,
            },
        )
    )
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="employees",
            record_id=str(emp.employee_id),
            old_value={"primary_store_id": from_store_id},
            new_value={"primary_store_id": to_store_id},
        )
    )
    session.commit()

    return MoveResult(
        employee_id=emp.employee_id,
        employee_name=emp.employee_name,
        from_store_id=from_store_id,
        to_store_id=to_store_id,
        to_store_name=to_store.store_name,
    )


@router.get("/employees/search", response_model=list[StaffSearchResult])
def search_staff(
    name: str = Query(..., min_length=1),
    current: CurrentUser = Depends(require_roles(*SEARCH_ROLES)),
    session: Session = Depends(get_session),
):
    """Find staff by name across ALL tenant staff (the point of Request-staff is
    to pull someone in from elsewhere). Capped at 25 results."""
    q = name.strip().lower()
    if not q:
        return []

    employees = session.exec(
        select(Employees).where(Employees.tenant_id == current.tenant_id)
    ).all()
    matches = [e for e in employees if q in e.employee_name.lower()][:25]
    if not matches:
        return []

    stores = {
        s.store_id: s
        for s in session.exec(
            select(Stores).where(Stores.tenant_id == current.tenant_id)
        ).all()
    }
    brands = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    match_ids = [e.employee_id for e in matches]
    add_by_emp: dict[int, list[int]] = {}
    for link in session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id.in_(match_ids)
        )
    ).all():
        add_by_emp.setdefault(link.employee_id, []).append(link.store_id)

    results: list[StaffSearchResult] = []
    for emp in matches:
        store_ids: list[int] = []
        if emp.primary_store_id is not None:
            store_ids.append(emp.primary_store_id)
        store_ids.extend(add_by_emp.get(emp.employee_id, []))

        store_names: list[str] = []
        brand_names: list[str] = []
        seen_stores: set[int] = set()
        seen_brands: set[int] = set()
        for sid in store_ids:
            st = stores.get(sid)
            if st is None or sid in seen_stores:
                continue
            seen_stores.add(sid)
            store_names.append(st.store_name)
            if st.brand_id not in seen_brands:
                seen_brands.add(st.brand_id)
                brand_names.append(brands.get(st.brand_id, ""))

        results.append(
            StaffSearchResult(
                employee_id=emp.employee_id,
                employee_name=emp.employee_name,
                brand_names=brand_names,
                store_names=store_names,
            )
        )
    return results


@router.post(
    "/employees/{employee_id}/request-assignment",
    response_model=RequestAssignmentResult,
    status_code=status.HTTP_201_CREATED,
)
def request_assignment(
    employee_id: int,
    payload: RequestAssignmentRequest,
    current: CurrentUser = Depends(require_roles(*AM_ONLY)),
    session: Session = Depends(get_session),
):
    """Queue a request to assign a staffer to one of the AM's stores. Makes NO
    change to the employee — it notifies Admins to action later. No dedupe."""
    _manager, _brand_ids, store_ids = _am_scope(current, session)

    if payload.store_id not in store_ids:
        raise HTTPException(
            status_code=400, detail="Requested store is not in your cluster."
        )
    store = session.get(Stores, payload.store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=400, detail="Requested store not found.")

    emp = session.get(Employees, employee_id)
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

    return RequestAssignmentResult(status="requested", notification_id=notif.notification_id)


@router.post(
    "/employees/{employee_id}/assign-store",
    response_model=AssignStoreResult,
    status_code=status.HTTP_201_CREATED,
)
def assign_store(
    employee_id: int,
    payload: AssignStoreRequest,
    current: CurrentUser = Depends(require_roles(*AM_ONLY)),
    session: Session = Depends(get_session),
):
    """Assign a staffer to an ADDITIONAL store within the AM's cluster (their
    primary store is unchanged; stores accumulate). Notifies IT."""
    _manager, _brand_ids, store_ids = _am_scope(current, session)

    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")

    # The staffer must already be in the AM's cluster (primary or additional).
    add_links = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id == employee_id
        )
    ).all()
    in_cluster = emp.primary_store_id in store_ids or any(
        link.store_id in store_ids for link in add_links
    )
    if not in_cluster:
        raise HTTPException(
            status_code=403, detail="This staff member is not in your cluster."
        )

    store_id = payload.store_id
    if store_id not in store_ids:
        raise HTTPException(
            status_code=400, detail="That store is not in your cluster."
        )
    if store_id == emp.primary_store_id:
        raise HTTPException(
            status_code=400, detail="That is already their primary store."
        )
    if any(link.store_id == store_id for link in add_links):
        raise HTTPException(
            status_code=400,
            detail="They are already assigned to that store.",
        )
    store = session.get(Stores, store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=400, detail="Store not found.")

    session.add(
        EmployeeAdditionalStores(employee_id=employee_id, store_id=store_id)
    )
    session.commit()

    session.add(
        Notifications(
            tenant_id=current.tenant_id,
            recipient_role="IT",
            type="STAFF_ASSIGNED",
            payload={
                "employee_id": emp.employee_id,
                "employee_name": emp.employee_name,
                "store_id": store.store_id,
                "store_name": store.store_name,
                "by_user_id": current.user_id,
                "by_username": current.username,
            },
        )
    )
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="employee_additional_stores",
            record_id=f"{employee_id}:{store_id}",
            old_value=None,
            new_value={"employee_id": employee_id, "store_id": store_id},
        )
    )
    session.commit()

    return AssignStoreResult(
        employee_id=emp.employee_id,
        employee_name=emp.employee_name,
        store_id=store.store_id,
        store_name=store.store_name,
    )

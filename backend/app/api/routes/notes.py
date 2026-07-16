"""Individual staff page + staff notes with per-note visibility.

Default visibility is private (author + Super Admin only). An author may share a
note with roles and/or brands; brand-shared notes are visible to Area Managers of
those brands. Super Admin sees everything; Admin/HR see a note only if it's shared
to their role.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.app_settings import get_bool
from app.core.database import get_session
from app.models.models import (
    ALLOWED_ROLES,
    AreaManagerBrands,
    AreaManagers,
    AuditLogs,
    Brands,
    Employees,
    EmployeeAdditionalStores,
    Positions,
    StaffNotes,
    Stores,
    Users,
)
from app.schemas.auth import CurrentUser
from app.schemas.notes import (
    NoteCreate,
    NoteFeedItem,
    NoteRead,
    NoteUpdate,
    StaffPageEmployee,
)

router = APIRouter(prefix="/api/v1/staff", tags=["staff-notes"])

# "Area Manager and above" — who may open the staff page and author notes.
STAFF_ROLES = ("Area Manager", "HR", "Admin", "Super Admin", "IT")


def _am_brand_ids(current: CurrentUser, session: Session) -> set[int]:
    manager = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == current.user_id)
    ).first()
    if manager is None:
        return set()
    return {
        link.brand_id
        for link in session.exec(
            select(AreaManagerBrands).where(
                AreaManagerBrands.manager_id == manager.manager_id
            )
        ).all()
    }


def _am_store_ids(current: CurrentUser, session: Session, brand_ids: set[int]) -> set[int]:
    if not brand_ids:
        return set()
    return {
        s.store_id
        for s in session.exec(
            select(Stores).where(
                Stores.tenant_id == current.tenant_id,
                Stores.brand_id.in_(brand_ids),
            )
        ).all()
    }


def _get_viewable_employee(
    employee_id: int, current: CurrentUser, session: Session
) -> Employees:
    """Fetch an employee the caller is allowed to view, else 404. Admin/HR/Super
    Admin see all; an Area Manager only staff in their cluster."""
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")

    if current.has_role("Super Admin", "Admin", "HR", "IT"):
        return emp

    # Area Manager: employee must be in their cluster (primary or additional).
    store_ids = _am_store_ids(current, session, _am_brand_ids(current, session))
    if emp.primary_store_id in store_ids:
        return emp
    add = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id == employee_id
        )
    ).all()
    if any(link.store_id in store_ids for link in add):
        return emp
    raise HTTPException(status_code=404, detail="Employee not found.")


def _note_visible(
    note: StaffNotes, current: CurrentUser, am_brand_ids: set[int]
) -> bool:
    if note.author_user_id == current.user_id:
        return True
    if current.has_role("Super Admin"):
        return True
    if current.has_role(*(note.visibility_roles or [])):
        return True
    if am_brand_ids and set(note.visibility_brand_ids or []) & am_brand_ids:
        return True
    return False


def _visibility_label(
    roles: list[str], brand_ids: list[int], brand_names: dict[int, str]
) -> str:
    if not roles and not brand_ids:
        return "Private"
    parts: list[str] = []
    if roles:
        parts.append(", ".join(roles))
    if brand_ids:
        parts.append(
            "Brand: " + ", ".join(brand_names.get(b, f"#{b}") for b in brand_ids)
        )
    return " · ".join(parts)


def _to_read(
    note: StaffNotes,
    current: CurrentUser,
    author_name: str,
    brand_names: dict[int, str],
) -> NoteRead:
    roles = list(note.visibility_roles or [])
    brand_ids = list(note.visibility_brand_ids or [])
    return NoteRead(
        note_id=note.note_id,
        employee_id=note.employee_id,
        note_text=note.note_text,
        author_user_id=note.author_user_id,
        author_name=author_name,
        created_at=note.created_at,
        visibility_roles=roles,
        visibility_brand_ids=brand_ids,
        visibility_label=_visibility_label(roles, brand_ids, brand_names),
        can_edit=(
            note.author_user_id == current.user_id
            or current.has_role("Super Admin")
        ),
    )


@router.get("/{employee_id}", response_model=StaffPageEmployee)
def staff_page(
    employee_id: int,
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Header details for the individual staff page."""
    emp = _get_viewable_employee(employee_id, current, session)
    store = (
        session.get(Stores, emp.primary_store_id)
        if emp.primary_store_id is not None
        else None
    )
    brand = session.get(Brands, store.brand_id) if store is not None else None
    position = (
        session.get(Positions, emp.position_id)
        if emp.position_id is not None
        else None
    )
    return StaffPageEmployee(
        employee_id=emp.employee_id,
        employee_name=emp.employee_name,
        payroll_id=emp.payroll_id,
        position_title=position.position_title if position else None,
        store_name=store.store_name if store else None,
        brand_id=store.brand_id if store else None,
        brand_name=brand.brand_name if brand else None,
    )


@router.get("/{employee_id}/notes", response_model=list[NoteRead])
def list_notes(
    employee_id: int,
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Notes on an employee that are visible to the caller, newest first."""
    _get_viewable_employee(employee_id, current, session)
    am_brands = _am_brand_ids(current, session) if current.has_role("Area Manager") else set()

    notes = session.exec(
        select(StaffNotes)
        .where(StaffNotes.employee_id == employee_id)
        .order_by(StaffNotes.created_at.desc())
    ).all()
    visible = [n for n in notes if _note_visible(n, current, am_brands)]
    if not visible:
        return []

    authors = {
        u.user_id: u.username
        for u in session.exec(
            select(Users).where(
                Users.user_id.in_({n.author_user_id for n in visible})
            )
        ).all()
    }
    brand_names = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    return [
        _to_read(n, current, authors.get(n.author_user_id, "Unknown"), brand_names)
        for n in visible
    ]


def _viewable_employees(
    current: CurrentUser, session: Session
) -> dict[int, str]:
    """employee_id -> name for every employee the caller may view."""
    tenant = current.tenant_id
    if current.has_role("Super Admin", "Admin", "HR", "IT"):
        rows = session.exec(
            select(Employees).where(Employees.tenant_id == tenant)
        ).all()
        return {e.employee_id: e.employee_name for e in rows}

    # Area Manager: employees whose primary or additional store is in the cluster.
    store_ids = _am_store_ids(current, session, _am_brand_ids(current, session))
    if not store_ids:
        return {}
    emp_map: dict[int, str] = {}
    for e in session.exec(
        select(Employees).where(
            Employees.tenant_id == tenant,
            Employees.primary_store_id.in_(store_ids),
        )
    ).all():
        emp_map[e.employee_id] = e.employee_name
    add_ids = {
        link.employee_id
        for link in session.exec(
            select(EmployeeAdditionalStores).where(
                EmployeeAdditionalStores.store_id.in_(store_ids)
            )
        ).all()
    }
    missing = add_ids - emp_map.keys()
    if missing:
        for e in session.exec(
            select(Employees).where(
                Employees.tenant_id == tenant,
                Employees.employee_id.in_(missing),
            )
        ).all():
            emp_map[e.employee_id] = e.employee_name
    return emp_map


@router.get("/notes/all", response_model=list[NoteFeedItem])
def notes_feed(
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Every note the caller may see, across all staff they can view, newest
    first. Backs the 'Staff Notes' dashboard tile."""
    emp_names = _viewable_employees(current, session)
    if not emp_names:
        return []
    am_brands = _am_brand_ids(current, session) if current.has_role("Area Manager") else set()

    notes = session.exec(
        select(StaffNotes)
        .where(StaffNotes.employee_id.in_(emp_names.keys()))
        .order_by(StaffNotes.created_at.desc())
    ).all()
    visible = [n for n in notes if _note_visible(n, current, am_brands)]
    if not visible:
        return []

    authors = {
        u.user_id: u.username
        for u in session.exec(
            select(Users).where(
                Users.user_id.in_({n.author_user_id for n in visible})
            )
        ).all()
    }
    brand_names = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    return [
        NoteFeedItem(
            note_id=n.note_id,
            employee_id=n.employee_id,
            employee_name=emp_names.get(n.employee_id, "Unknown"),
            note_text=n.note_text,
            author_user_id=n.author_user_id,
            author_name=authors.get(n.author_user_id, "Unknown"),
            created_at=n.created_at,
            visibility_roles=list(n.visibility_roles or []),
            visibility_brand_ids=list(n.visibility_brand_ids or []),
            visibility_label=_visibility_label(
                list(n.visibility_roles or []),
                list(n.visibility_brand_ids or []),
                brand_names,
            ),
            can_edit=(
                n.author_user_id == current.user_id
                or current.has_role("Super Admin")
            ),
        )
        for n in visible
    ]


def _validate_visibility(
    roles: list[str], brand_ids: list[int], tenant: int, session: Session
) -> tuple[list[str], list[int]]:
    clean_roles: list[str] = []
    for r in roles or []:
        if r not in ALLOWED_ROLES:
            raise HTTPException(status_code=422, detail=f"Unknown role '{r}'.")
        if r not in clean_roles:
            clean_roles.append(r)
    clean_brands: list[int] = []
    for bid in brand_ids or []:
        b = session.get(Brands, bid)
        if b is None or b.tenant_id != tenant:
            raise HTTPException(status_code=422, detail=f"Unknown brand id {bid}.")
        if bid not in clean_brands:
            clean_brands.append(bid)
    return clean_roles, clean_brands


@router.post(
    "/{employee_id}/notes",
    response_model=NoteRead,
    status_code=status.HTTP_201_CREATED,
)
def create_note(
    employee_id: int,
    payload: NoteCreate,
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Add a note to an employee. Author is the caller; visibility defaults to
    private (empty roles + brands)."""
    if not get_bool(session, current.tenant_id, "staff_notes_enabled", True):
        raise HTTPException(
            status_code=403, detail="Staff notes are disabled by an administrator."
        )
    _get_viewable_employee(employee_id, current, session)

    text_val = (payload.note_text or "").strip()
    if not text_val:
        raise HTTPException(status_code=422, detail="Note text is required.")

    roles, brand_ids = _validate_visibility(
        payload.visibility_roles, payload.visibility_brand_ids, current.tenant_id, session
    )

    note = StaffNotes(
        employee_id=employee_id,
        author_user_id=current.user_id,
        note_text=text_val,
        visibility_roles=roles,
        visibility_brand_ids=brand_ids,
    )
    session.add(note)
    session.commit()
    session.refresh(note)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="staff_notes",
            record_id=str(note.note_id),
            old_value=None,
            new_value={"employee_id": employee_id, "roles": roles, "brands": brand_ids},
        )
    )
    session.commit()

    brand_names = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    return _to_read(note, current, current.username, brand_names)


def _load_editable_note(
    note_id: int, current: CurrentUser, session: Session
) -> StaffNotes:
    note = session.get(StaffNotes, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="Note not found.")
    emp = session.get(Employees, note.employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Note not found.")
    if note.author_user_id != current.user_id and not current.has_role("Super Admin"):
        raise HTTPException(
            status_code=403, detail="Only the author or a Super Admin can change this note."
        )
    return note


@router.patch("/notes/{note_id}", response_model=NoteRead)
def update_note(
    note_id: int,
    payload: NoteUpdate,
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Edit a note's text and/or visibility (author or Super Admin)."""
    if not get_bool(session, current.tenant_id, "staff_notes_enabled", True):
        raise HTTPException(
            status_code=403, detail="Staff notes are disabled by an administrator."
        )
    note = _load_editable_note(note_id, current, session)

    if payload.note_text is not None:
        t = payload.note_text.strip()
        if not t:
            raise HTTPException(status_code=422, detail="Note text is required.")
        note.note_text = t
    if payload.visibility_roles is not None or payload.visibility_brand_ids is not None:
        roles, brand_ids = _validate_visibility(
            payload.visibility_roles
            if payload.visibility_roles is not None
            else note.visibility_roles,
            payload.visibility_brand_ids
            if payload.visibility_brand_ids is not None
            else note.visibility_brand_ids,
            current.tenant_id,
            session,
        )
        note.visibility_roles = roles
        note.visibility_brand_ids = brand_ids

    session.add(note)
    session.commit()
    session.refresh(note)

    author = session.get(Users, note.author_user_id)
    brand_names = {
        b.brand_id: b.brand_name
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    return _to_read(
        note, current, author.username if author else "Unknown", brand_names
    )


@router.delete("/notes/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(
    note_id: int,
    current: CurrentUser = Depends(require_roles(*STAFF_ROLES)),
    session: Session = Depends(get_session),
):
    """Delete a note (author or Super Admin)."""
    note = _load_editable_note(note_id, current, session)
    emp_id = note.employee_id
    session.delete(note)
    session.commit()
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table="staff_notes",
            record_id=str(note_id),
            old_value={"employee_id": emp_id},
            new_value=None,
        )
    )
    session.commit()
    return None

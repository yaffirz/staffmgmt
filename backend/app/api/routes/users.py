from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.core.security import hash_password
from app.models.models import (
    ALLOWED_ROLES as MODEL_ALLOWED_ROLES,
    AreaManagerBrands,
    AreaManagers,
    AreaManagerStores,
    AuditLogs,
    Brands,
    UserRoles,
    Users,
)
from app.schemas.auth import CurrentUser
from app.schemas.user import UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/api/v1/users", tags=["users"])

# Creating/editing accounts and AM brand scope — Admins and Super Admins only.
MANAGE_ROLES = ("Super Admin", "Admin")
ALLOWED_ROLES = set(MODEL_ALLOWED_ROLES)


def _additional_roles_of(session: Session, user_id: int) -> list[str]:
    return [
        r.role
        for r in session.exec(
            select(UserRoles).where(UserRoles.user_id == user_id)
        ).all()
    ]


def _set_additional_roles(
    session: Session, user: Users, roles: list[str]
) -> None:
    """Replace a user's additional roles. Validates against ALLOWED_ROLES and
    never stores the primary role as an 'additional' one."""
    clean: list[str] = []
    for r in roles:
        if r not in ALLOWED_ROLES:
            raise HTTPException(status_code=422, detail=f"Unknown role '{r}'.")
        if r != user.role and r not in clean:
            clean.append(r)
    for existing in session.exec(
        select(UserRoles).where(UserRoles.user_id == user.user_id)
    ).all():
        session.delete(existing)
    for r in clean:
        session.add(UserRoles(user_id=user.user_id, role=r))
    session.commit()


def _manager_for(session: Session, user: Users) -> AreaManagers:
    """Get or create the area_managers row backing an AM user."""
    m = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user.user_id)
    ).first()
    if m is None:
        m = AreaManagers(user_id=user.user_id, manager_name=user.username)
        session.add(m)
        session.commit()
        session.refresh(m)
    return m


def _remove_area_manager(session: Session, user_id: int) -> None:
    """Drop area_managers row + brand/store links for a user."""
    managers = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user_id)
    ).all()
    for m in managers:
        for b in session.exec(
            select(AreaManagerBrands).where(
                AreaManagerBrands.manager_id == m.manager_id
            )
        ).all():
            session.delete(b)
        for s in session.exec(
            select(AreaManagerStores).where(
                AreaManagerStores.manager_id == m.manager_id
            )
        ).all():
            session.delete(s)
        session.delete(m)


def _set_brands(
    session: Session, manager_id: int, brand_ids: list[int], tenant: int
) -> None:
    """Replace an AM's brand set with the given brand_ids (validated)."""
    # Validate brands exist in this tenant.
    clean: list[int] = []
    for bid in brand_ids:
        b = session.get(Brands, bid)
        if b is None or b.tenant_id != tenant:
            raise HTTPException(
                status_code=422, detail=f"Unknown brand id {bid}."
            )
        if bid not in clean:
            clean.append(bid)
    # Clear existing then add.
    for existing in session.exec(
        select(AreaManagerBrands).where(
            AreaManagerBrands.manager_id == manager_id
        )
    ).all():
        session.delete(existing)
    for bid in clean:
        session.add(AreaManagerBrands(manager_id=manager_id, brand_id=bid))
    session.commit()


def _brands_of(session: Session, user: Users) -> tuple[list[int], list[str]]:
    m = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user.user_id)
    ).first()
    if m is None:
        return [], []
    rows = session.exec(
        select(AreaManagerBrands).where(
            AreaManagerBrands.manager_id == m.manager_id
        )
    ).all()
    ids = [r.brand_id for r in rows]
    names = []
    for bid in ids:
        b = session.get(Brands, bid)
        if b is not None:
            names.append(b.brand_name)
    return ids, names


def _read(session: Session, user: Users) -> UserRead:
    ids, names = ([], [])
    if user.role == "Area Manager":
        ids, names = _brands_of(session, user)
    additional = _additional_roles_of(session, user.user_id)
    return UserRead(
        user_id=user.user_id,
        username=user.username,
        email=user.email,
        role=user.role,
        roles=list(dict.fromkeys([user.role, *additional])),
        additional_roles=additional,
        brand_ids=ids,
        brand_names=names,
    )


def _validate_email(email: str) -> str:
    e = email.strip()
    if not e or "@" not in e or "." not in e.split("@")[-1]:
        raise HTTPException(status_code=422, detail="A valid email is required.")
    return e


@router.get("", response_model=list[UserRead])
def list_users(
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    users = session.exec(
        select(Users)
        .where(Users.tenant_id == current.tenant_id)
        .order_by(Users.role, Users.username)
    ).all()
    return [_read(session, u) for u in users]


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    username = payload.username.strip()
    if not username:
        raise HTTPException(status_code=422, detail="Username is required.")
    email = _validate_email(payload.email)
    if len(payload.password) < 6:
        raise HTTPException(
            status_code=422, detail="Password must be at least 6 characters."
        )
    if payload.role not in ALLOWED_ROLES:
        raise HTTPException(status_code=422, detail="Unknown role.")

    tenant = current.tenant_id
    if session.exec(
        select(Users)
        .where(Users.tenant_id == tenant)
        .where(Users.username == username)
    ).first():
        raise HTTPException(
            status_code=409, detail=f"Username '{username}' already exists."
        )
    if session.exec(
        select(Users).where(Users.tenant_id == tenant).where(Users.email == email)
    ).first():
        raise HTTPException(
            status_code=409, detail=f"Email '{email}' is already in use."
        )

    user = Users(
        tenant_id=tenant,
        username=username,
        email=email,
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    session.add(user)
    session.commit()
    session.refresh(user)

    if user.role == "Area Manager":
        m = _manager_for(session, user)
        _set_brands(session, m.manager_id, payload.brand_ids or [], tenant)

    if payload.additional_roles is not None:
        if not current.has_role("Super Admin"):
            raise HTTPException(
                status_code=403,
                detail="Only a Super Admin can assign additional roles.",
            )
        _set_additional_roles(session, user, payload.additional_roles)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="users",
            record_id=str(user.user_id),
            old_value=None,
            new_value={"username": username, "email": email, "role": user.role},
        )
    )
    session.commit()
    return _read(session, user)


@router.patch("/{user_id}", response_model=UserRead)
def update_user(
    user_id: int,
    payload: UserUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    user = session.get(Users, user_id)
    if user is None or user.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="User not found.")
    tenant = current.tenant_id
    changes: dict = {}

    if payload.username is not None:
        uname = payload.username.strip()
        if not uname:
            raise HTTPException(status_code=422, detail="Username is required.")
        if uname != user.username:
            dup = session.exec(
                select(Users)
                .where(Users.tenant_id == tenant)
                .where(Users.username == uname)
            ).first()
            if dup is not None and dup.user_id != user_id:
                raise HTTPException(
                    status_code=409,
                    detail=f"Username '{uname}' already exists.",
                )
            user.username = uname
            changes["username"] = uname

    if payload.email is not None:
        email = _validate_email(payload.email)
        if email != user.email:
            dup = session.exec(
                select(Users)
                .where(Users.tenant_id == tenant)
                .where(Users.email == email)
            ).first()
            if dup is not None and dup.user_id != user_id:
                raise HTTPException(
                    status_code=409,
                    detail=f"Email '{email}' is already in use.",
                )
            user.email = email
            changes["email"] = email

    if payload.role is not None and payload.role != user.role:
        if user_id == current.user_id:
            raise HTTPException(
                status_code=400, detail="You cannot change your own role."
            )
        if payload.role not in ALLOWED_ROLES:
            raise HTTPException(status_code=422, detail="Unknown role.")
        was_am = user.role == "Area Manager"
        user.role = payload.role
        changes["role"] = payload.role
        if payload.role == "Area Manager":
            _manager_for(session, user)
        elif was_am:
            _remove_area_manager(session, user.user_id)

    if payload.password is not None:
        if len(payload.password) < 6:
            raise HTTPException(
                status_code=422,
                detail="Password must be at least 6 characters.",
            )
        user.password_hash = hash_password(payload.password)
        changes["password"] = "reset"

    if changes:
        session.add(user)
        session.commit()
        session.refresh(user)

    # Brand set (only meaningful for AMs). Apply after any role change.
    if payload.brand_ids is not None and user.role == "Area Manager":
        m = _manager_for(session, user)
        _set_brands(session, m.manager_id, payload.brand_ids, tenant)
        changes["brands"] = payload.brand_ids

    # Additional roles (multi-role) — Super Admin only.
    if payload.additional_roles is not None:
        if not current.has_role("Super Admin"):
            raise HTTPException(
                status_code=403,
                detail="Only a Super Admin can assign additional roles.",
            )
        _set_additional_roles(session, user, payload.additional_roles)
        changes["additional_roles"] = payload.additional_roles

    if changes:
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="UPDATE",
                affected_table="users",
                record_id=str(user.user_id),
                old_value=None,
                new_value=changes,
            )
        )
        session.commit()

    return _read(session, user)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    if user_id == current.user_id:
        raise HTTPException(
            status_code=400, detail="You cannot delete your own account."
        )
    user = session.get(Users, user_id)
    if user is None or user.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="User not found.")

    snap = {"username": user.username, "email": user.email, "role": user.role}
    if user.role == "Area Manager":
        _remove_area_manager(session, user.user_id)
    for r in session.exec(
        select(UserRoles).where(UserRoles.user_id == user.user_id)
    ).all():
        session.delete(r)
    session.delete(user)
    session.commit()
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table="users",
            record_id=str(user_id),
            old_value=snap,
            new_value=None,
        )
    )
    session.commit()
    return None

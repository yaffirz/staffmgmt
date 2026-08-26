from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_
from sqlmodel import Session, select

from app.api.deps import get_current_user
from app.core.database import get_session
from app.core.security import create_access_token, hash_password, verify_password
from app.models.models import (
    AreaManagerBrands,
    AreaManagers,
    Brands,
    UserRoles,
    Users,
)
from app.schemas.auth import (
    ChangePasswordRequest,
    CurrentUser,
    LoginRequest,
    TokenResponse,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def effective_roles(session: Session, user: Users) -> list[str]:
    """A user's primary role plus any additional roles, deduped, primary first."""
    additional = [
        r.role
        for r in session.exec(
            select(UserRoles).where(UserRoles.user_id == user.user_id)
        ).all()
    ]
    return list(dict.fromkeys([user.role, *additional]))


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, session: Session = Depends(get_session)):
    """Validate credentials and return a JWT carrying role + tenant_id.
    The identifier may be a username or an email, matched case-insensitively."""
    ident = (payload.username or "").strip()
    lowered = ident.lower()
    matches = session.exec(
        select(Users).where(
            or_(
                func.lower(Users.username) == lowered,
                func.lower(Users.email) == lowered,
            )
        )
    ).all()
    # Prefer an exact match if two accounts collide only by letter case.
    user = next(
        (u for u in matches if u.username == ident or (u.email or "") == ident),
        matches[0] if matches else None,
    )

    # Same generic error whether the username or the password is wrong.
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    if user.suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is suspended. Contact an administrator.",
        )

    roles = effective_roles(session, user)
    token = create_access_token(
        subject=user.username,
        role=user.role,
        tenant_id=user.tenant_id,
        user_id=user.user_id,
        roles=roles,
    )
    return TokenResponse(
        access_token=token,
        role=user.role,
        roles=roles,
        user_id=user.user_id,
        tenant_id=user.tenant_id,
        must_change_password=user.must_change_password,
    )


@router.get("/me", response_model=CurrentUser)
def me(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Quick check that a token is valid and decodes to the right identity.
    Also reports whether the user must change their password (read live from the
    DB so the flag reflects any change made since the token was issued)."""
    user = session.get(Users, current.user_id)
    current.must_change_password = bool(user and user.must_change_password)
    return current


@router.post("/change-password", response_model=CurrentUser)
def change_password(
    payload: ChangePasswordRequest,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """The signed-in user sets their own new password (used by the forced-change
    screen). Clears the must_change_password flag."""
    if len(payload.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Password must be at least 6 characters.",
        )
    user = session.get(Users, current.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found.")
    user.password_hash = hash_password(payload.new_password)
    user.must_change_password = False
    session.add(user)
    session.commit()
    current.must_change_password = False
    return current


@router.get("/me/brands")
def my_brands(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """The current user's own brands (Area Managers). Used to default the
    brand picker when sharing a staff note 'by brand'. Empty for non-AMs."""
    manager = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == current.user_id)
    ).first()
    if manager is None:
        return []
    brand_ids = [
        link.brand_id
        for link in session.exec(
            select(AreaManagerBrands).where(
                AreaManagerBrands.manager_id == manager.manager_id
            )
        ).all()
    ]
    if not brand_ids:
        return []
    brands = session.exec(
        select(Brands).where(
            Brands.tenant_id == current.tenant_id,
            Brands.brand_id.in_(brand_ids),
        )
    ).all()
    return [{"brand_id": b.brand_id, "brand_name": b.brand_name} for b in brands]

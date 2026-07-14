from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import get_current_user
from app.core.database import get_session
from app.core.security import create_access_token, verify_password
from app.models.models import AreaManagerBrands, AreaManagers, Brands, Users
from app.schemas.auth import CurrentUser, LoginRequest, TokenResponse

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, session: Session = Depends(get_session)):
    """Validate credentials and return a JWT carrying role + tenant_id."""
    user = session.exec(
        select(Users).where(Users.username == payload.username)
    ).first()

    # Same generic error whether the username or the password is wrong.
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    token = create_access_token(
        subject=user.username,
        role=user.role,
        tenant_id=user.tenant_id,
        user_id=user.user_id,
    )
    return TokenResponse(
        access_token=token,
        role=user.role,
        user_id=user.user_id,
        tenant_id=user.tenant_id,
    )


@router.get("/me", response_model=CurrentUser)
def me(current: CurrentUser = Depends(get_current_user)):
    """Quick check that a token is valid and decodes to the right identity."""
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

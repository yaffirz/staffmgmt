import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session

from app.core.database import get_session
from app.core.security import decode_access_token
from app.models.models import Users
from app.schemas.auth import CurrentUser

# Renders the "Authorize" button in /docs and reads "Authorization: Bearer <token>".
bearer_scheme = HTTPBearer(auto_error=True)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    session: Session = Depends(get_session),
) -> CurrentUser:
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired"
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )

    try:
        # Old tokens (pre multi-role) have no "roles" claim — fall back to [role].
        roles = payload.get("roles") or [payload["role"]]
        user_id = payload["user_id"]
        username = payload["sub"]
        role = payload["role"]
        tenant_id = payload["tenant_id"]
    except KeyError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token payload"
        )

    # Suspension is enforced on every request, so suspending a user cuts off any
    # live session on its next call (not just future logins).
    user = session.get(Users, user_id)
    if user is not None and user.suspended:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is suspended.",
        )

    return CurrentUser(
        user_id=user_id,
        username=username,
        role=role,
        roles=roles,
        tenant_id=tenant_id,
    )


def require_roles(*allowed_roles: str):
    """Dependency factory: restrict an endpoint to the given roles.

    Usage:  @router.get(..., dependencies=[Depends(require_roles("Admin", "HR"))])
    """

    def _checker(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        # Allow if ANY of the user's effective roles is permitted.
        if not current.has_role(*allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )
        return current

    return _checker

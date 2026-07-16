import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import decode_access_token
from app.schemas.auth import CurrentUser

# Renders the "Authorize" button in /docs and reads "Authorization: Bearer <token>".
bearer_scheme = HTTPBearer(auto_error=True)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
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
        return CurrentUser(
            user_id=payload["user_id"],
            username=payload["sub"],
            role=payload["role"],
            roles=roles,
            tenant_id=payload["tenant_id"],
        )
    except KeyError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token payload"
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

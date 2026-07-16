from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    roles: list[str] = []
    user_id: int
    tenant_id: int


class CurrentUser(BaseModel):
    user_id: int
    username: str
    role: str  # primary role
    roles: list[str] = []  # effective roles (primary + additional)
    tenant_id: int

    def has_role(self, *any_of: str) -> bool:
        """True if the user holds any of the given roles (effective set)."""
        return bool(set(any_of) & set(self.roles or [self.role]))

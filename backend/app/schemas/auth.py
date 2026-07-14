from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int
    tenant_id: int


class CurrentUser(BaseModel):
    user_id: int
    username: str
    role: str
    tenant_id: int

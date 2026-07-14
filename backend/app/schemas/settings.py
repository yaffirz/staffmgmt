from pydantic import BaseModel


class SettingRead(BaseModel):
    key: str
    value: str


class SettingUpdate(BaseModel):
    value: str

from pydantic import BaseModel


class FormFieldConfigRead(BaseModel):
    form_key: str
    field_key: str
    label: str
    enabled: bool
    required: bool
    locked: bool
    sort_order: int


class FormFieldUpdate(BaseModel):
    field_key: str
    enabled: bool
    required: bool


class FormConfigUpdate(BaseModel):
    fields: list[FormFieldUpdate]

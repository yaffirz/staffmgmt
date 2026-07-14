from pydantic import BaseModel


class StoreStaffMember(BaseModel):
    employee_id: int
    employee_name: str
    payroll_id: str
    position_title: str | None = None
    # True when the staffer is here via an additional-store link (primary is
    # elsewhere); False when this is their primary store.
    also_covers: bool


class StoreStaffResponse(BaseModel):
    store_id: int
    store_name: str
    brand_id: int
    brand_name: str
    staff: list[StoreStaffMember]

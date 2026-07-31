from pydantic import BaseModel


class StoreStaffLite(BaseModel):
    """Deliberately minimal — Store/Foodmall accounts see name only."""

    employee_id: int
    name: str


class StoreBrandGroup(BaseModel):
    brand_id: int
    brand_name: str
    staff: list[StoreStaffLite]


class StoreSummary(BaseModel):
    store_id: int
    store_name: str
    is_foodmall: bool
    groups: list[StoreBrandGroup]  # one per brand the store carries


class StoreRequestStaff(BaseModel):
    employee_id: int

from pydantic import BaseModel


# ---- Cluster read view (Phase 2a) ----------------------------------------
class ClusterStaff(BaseModel):
    employee_id: int
    employee_name: str
    position_title: str | None = None
    # True when the staffer appears here via an additional-store link (their
    # primary store is elsewhere) — shown as an "also covers" tag, and NOT movable
    # from this store.
    also_covers: bool


class ClusterStore(BaseModel):
    store_id: int
    store_name: str
    brand_id: int
    brand_name: str
    staff: list[ClusterStaff]


class ClusterResponse(BaseModel):
    stores: list[ClusterStore]


# ---- Move staff (Flow 1) --------------------------------------------------
class MoveRequest(BaseModel):
    to_store_id: int


class MoveResult(BaseModel):
    employee_id: int
    employee_name: str
    from_store_id: int
    to_store_id: int
    to_store_name: str


# ---- Request staff (Flow 2) ----------------------------------------------
class StaffSearchResult(BaseModel):
    employee_id: int
    employee_name: str
    brand_names: list[str]
    store_names: list[str]


class RequestAssignmentRequest(BaseModel):
    store_id: int


class RequestAssignmentResult(BaseModel):
    status: str
    notification_id: int

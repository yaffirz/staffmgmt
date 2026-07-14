from pydantic import BaseModel


# ---- Read ----------------------------------------------------------------
class BrandRead(BaseModel):
    brand_id: int
    brand_name: str
    model_config = {"from_attributes": True}


class StoreRead(BaseModel):
    store_id: int
    brand_id: int
    store_name: str
    model_config = {"from_attributes": True}


class PositionRead(BaseModel):
    position_id: int
    brand_id: int
    position_title: str
    model_config = {"from_attributes": True}


class CountryRead(BaseModel):
    country_id: int
    country_name: str
    model_config = {"from_attributes": True}


# ---- Create (single) -----------------------------------------------------
class BrandCreate(BaseModel):
    brand_name: str


class StoreCreate(BaseModel):
    brand_id: int
    store_name: str


class PositionCreate(BaseModel):
    brand_id: int
    position_title: str


# ---- Update (single) -----------------------------------------------------
class BrandUpdate(BaseModel):
    brand_name: str


class StoreUpdate(BaseModel):
    brand_id: int
    store_name: str


class PositionUpdate(BaseModel):
    brand_id: int
    position_title: str


# ---- Bulk result ---------------------------------------------------------
class BulkRowError(BaseModel):
    row: int  # human-friendly (header = row 1)
    message: str


class BulkResult(BaseModel):
    created: int
    skipped: int  # already existed
    errors: list[BulkRowError]

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
    is_foodmall: bool = False
    # Extra brands a foodmall store carries (beyond the primary brand_id).
    extra_brand_ids: list[int] = []
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
    is_foodmall: bool = False
    extra_brand_ids: list[int] = []


class PositionCreate(BaseModel):
    brand_id: int
    position_title: str


class CountryCreate(BaseModel):
    country_name: str


# ---- Update (single) -----------------------------------------------------
class BrandUpdate(BaseModel):
    brand_name: str


class StoreUpdate(BaseModel):
    brand_id: int
    store_name: str
    is_foodmall: bool = False
    extra_brand_ids: list[int] = []


class PositionUpdate(BaseModel):
    brand_id: int
    position_title: str


class CountryUpdate(BaseModel):
    country_name: str


# ---- Bulk result ---------------------------------------------------------
class BulkRowError(BaseModel):
    row: int  # human-friendly (header = row 1)
    message: str


class BulkResult(BaseModel):
    created: int
    skipped: int  # already existed
    errors: list[BulkRowError]

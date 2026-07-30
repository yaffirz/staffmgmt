from pydantic import BaseModel, field_validator

# Delivery channels for an announcement.
DELIVERY_BELL = "bell"
DELIVERY_POPUP = "popup"
ALLOWED_DELIVERY = (DELIVERY_BELL, DELIVERY_POPUP)


class AnnouncementCreate(BaseModel):
    title: str
    body: str
    delivery: str  # "bell" | "popup"

    @field_validator("title", "body")
    @classmethod
    def _not_blank(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("must not be blank")
        return v

    @field_validator("delivery")
    @classmethod
    def _valid_delivery(cls, v: str) -> str:
        if v not in ALLOWED_DELIVERY:
            raise ValueError(f"delivery must be one of {ALLOWED_DELIVERY}")
        return v


class AnnouncementResult(BaseModel):
    notification_id: int
    delivery: str

from pydantic import BaseModel


class MarketingContent(BaseModel):
    """Public login-screen marketing block."""

    enabled: bool
    type: str  # text | image | embed
    title: str
    content: str

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

BookingStatus = Literal["confirmed", "completed", "cancelled"]


class BookingCreate(BaseModel):
    customer_name: str = Field(min_length=1, max_length=120)
    customer_email: EmailStr
    service: str = Field(min_length=1, max_length=160)
    scheduled_at: datetime


class BookingStatusUpdate(BaseModel):
    status: BookingStatus


class BookingResponse(BookingCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: BookingStatus
    created_at: datetime

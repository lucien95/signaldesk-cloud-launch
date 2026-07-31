from datetime import UTC, datetime, timedelta
from typing import Literal
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from .services import BUSINESS_TIMEZONE, SERVICE_NAMES

BookingStatus = Literal["confirmed", "completed", "cancelled"]


class BookingCreate(BaseModel):
    customer_name: str = Field(min_length=1, max_length=120)
    customer_email: EmailStr
    service: str = Field(min_length=1, max_length=160)
    scheduled_at: datetime

    @field_validator("customer_name")
    @classmethod
    def normalize_customer_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("customer name is required")
        return normalized

    @field_validator("service")
    @classmethod
    def validate_service(cls, value: str) -> str:
        if value not in SERVICE_NAMES:
            raise ValueError("select a service from the published catalog")
        return value

    @field_validator("scheduled_at")
    @classmethod
    def validate_scheduled_at(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("appointment time must include a timezone")

        normalized = value.astimezone(UTC)
        if normalized < datetime.now(UTC) + timedelta(minutes=15):
            raise ValueError("appointment time must be at least 15 minutes in the future")

        local_time = normalized.astimezone(ZoneInfo(BUSINESS_TIMEZONE))
        if local_time.weekday() >= 5:
            raise ValueError("appointments are available Monday through Friday")
        if local_time.hour not in range(8, 18, 2) or local_time.minute != 0:
            raise ValueError("select one of the published appointment times")
        return normalized


class BookingStatusUpdate(BaseModel):
    status: BookingStatus


class BookingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    customer_name: str
    customer_email: EmailStr
    service: str
    scheduled_at: datetime
    status: BookingStatus
    created_at: datetime


class ServiceOption(BaseModel):
    id: str
    name: str
    duration_minutes: int
    price_from_usd: int
    description: str


class AvailabilitySlot(BaseModel):
    starts_at: datetime
    available: bool


class AvailabilityResponse(BaseModel):
    date: str
    timezone: str
    slots: list[AvailabilitySlot]

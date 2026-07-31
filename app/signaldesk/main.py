import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from datetime import UTC, date, datetime, timedelta
from datetime import time as datetime_time
from pathlib import Path
from zoneinfo import ZoneInfo

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response, status
from fastapi.staticfiles import StaticFiles
from sqlalchemy import or_, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .database import Base, engine, get_db
from .logging_config import configure_logging
from .models import Booking
from .schemas import (
    AvailabilityResponse,
    AvailabilitySlot,
    BookingCreate,
    BookingResponse,
    BookingStatus,
    BookingStatusUpdate,
    ServiceOption,
)
from .services import BUSINESS_TIMEZONE, SERVICE_CATALOG

configure_logging()
logger = logging.getLogger("signaldesk.api")


def normalized_request_id(value: str | None) -> str:
    if value is not None:
        try:
            return str(uuid.UUID(value))
        except ValueError:
            pass
    return str(uuid.uuid4())


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(bind=engine)
    logger.info("application_started")
    yield
    logger.info("application_stopped")


app = FastAPI(
    title="SignalDesk Booking API",
    description="Small-business booking API used by the SignalOps cloud launch lab.",
    version="0.1.0",
    lifespan=lifespan,
)


@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = normalized_request_id(request.headers.get("x-request-id"))
    started = time.perf_counter()
    try:
        response: Response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        logger.exception(
            "request_failed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "duration_ms": duration_ms,
            },
        )
        raise

    duration_ms = round((time.perf_counter() - started) * 1000, 2)
    response.headers["x-request-id"] = request_id
    if request.url.path.startswith(("/api/", "/health/")):
        response.headers["cache-control"] = "no-store"
    logger.info(
        "request_completed",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration_ms": duration_ms,
        },
    )
    return response


@app.get("/api/v1/meta", tags=["system"])
def metadata() -> dict[str, str]:
    return {
        "service": "signaldesk-api",
        "environment": os.getenv("APP_ENV", "local"),
        "docs": "/docs",
        "business_timezone": BUSINESS_TIMEZONE,
    }


@app.get("/health/live", tags=["health"])
def liveness() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready", tags=["health"])
def readiness(db: Session = Depends(get_db)) -> dict[str, str]:
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        logger.exception("database_readiness_failed")
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "ready"}


@app.post(
    "/api/v1/bookings",
    response_model=BookingResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["bookings"],
)
def create_booking(payload: BookingCreate, db: Session = Depends(get_db)) -> Booking:
    existing = db.scalar(
        select(Booking).where(
            Booking.scheduled_at == payload.scheduled_at,
            Booking.status != "cancelled",
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="that appointment time was just booked; choose another time",
        )

    booking = Booking(id=str(uuid.uuid4()), **payload.model_dump())
    try:
        db.add(booking)
        db.commit()
        db.refresh(booking)
    except SQLAlchemyError as exc:
        db.rollback()
        logger.exception("booking_create_failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="booking service is temporarily unavailable",
        ) from exc
    return booking


@app.get(
    "/api/v1/services",
    response_model=list[ServiceOption],
    tags=["bookings"],
)
def list_services() -> tuple[dict[str, object], ...]:
    return SERVICE_CATALOG


@app.get(
    "/api/v1/availability",
    response_model=AvailabilityResponse,
    tags=["bookings"],
)
def get_availability(
    day: date = Query(alias="date"),
    db: Session = Depends(get_db),
) -> AvailabilityResponse:
    business_zone = ZoneInfo(BUSINESS_TIMEZONE)
    local_start = datetime.combine(day, datetime_time.min, tzinfo=business_zone)
    local_end = local_start + timedelta(days=1)
    start_utc = local_start.astimezone(UTC)
    end_utc = local_end.astimezone(UTC)

    booked_times = set(
        db.scalars(
            select(Booking.scheduled_at).where(
                Booking.scheduled_at >= start_utc,
                Booking.scheduled_at < end_utc,
                Booking.status != "cancelled",
            )
        )
    )
    booked_utc = {
        booked.replace(tzinfo=UTC) if booked.tzinfo is None else booked.astimezone(UTC)
        for booked in booked_times
    }
    earliest = datetime.now(UTC) + timedelta(minutes=15)

    slots = []
    if day.weekday() < 5:
        for hour in range(8, 18, 2):
            starts_at = datetime.combine(
                day,
                datetime_time(hour=hour),
                tzinfo=business_zone,
            ).astimezone(UTC)
            slots.append(
                AvailabilitySlot(
                    starts_at=starts_at,
                    available=starts_at >= earliest and starts_at not in booked_utc,
                )
            )

    return AvailabilityResponse(
        date=day.isoformat(),
        timezone=BUSINESS_TIMEZONE,
        slots=slots,
    )


@app.get(
    "/api/v1/bookings",
    response_model=list[BookingResponse],
    tags=["bookings"],
)
def list_bookings(
    status_filter: BookingStatus | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None, min_length=1, max_length=120),
    limit: int = Query(default=100, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Booking]:
    query = select(Booking)
    if status_filter is not None:
        query = query.where(Booking.status == status_filter)
    if search is not None:
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(
                Booking.customer_name.ilike(pattern),
                Booking.customer_email.ilike(pattern),
                Booking.service.ilike(pattern),
                Booking.id.ilike(pattern),
            )
        )
    query = query.order_by(Booking.scheduled_at).limit(limit).offset(offset)
    return list(db.scalars(query))


@app.get(
    "/api/v1/bookings/{booking_id}",
    response_model=BookingResponse,
    tags=["bookings"],
)
def get_booking(booking_id: str, db: Session = Depends(get_db)) -> Booking:
    booking = db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="booking not found")
    return booking


@app.patch(
    "/api/v1/bookings/{booking_id}/status",
    response_model=BookingResponse,
    tags=["bookings"],
)
def update_booking_status(
    booking_id: str,
    payload: BookingStatusUpdate,
    db: Session = Depends(get_db),
) -> Booking:
    booking = db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="booking not found")
    if booking.status in {"completed", "cancelled"} and payload.status != booking.status:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"{booking.status} bookings cannot change status",
        )
    try:
        booking.status = payload.status
        db.commit()
        db.refresh(booking)
    except SQLAlchemyError as exc:
        db.rollback()
        logger.exception("booking_status_update_failed", extra={"booking_id": booking_id})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="booking service is temporarily unavailable",
        ) from exc
    return booking


frontend_directory = Path(
    os.getenv("FRONTEND_DIR", str(Path(__file__).resolve().parent / "static"))
).resolve()
if frontend_directory.is_dir():
    app.mount(
        "/",
        StaticFiles(directory=frontend_directory, html=True),
        name="frontend",
    )
else:

    @app.get("/", tags=["system"])
    def root() -> dict[str, str]:
        return metadata()

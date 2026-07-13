import logging
import os
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .database import Base, engine, get_db
from .logging_config import configure_logging
from .models import Booking
from .schemas import BookingCreate, BookingResponse, BookingStatusUpdate

configure_logging()
logger = logging.getLogger("signaldesk.api")


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
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    started = time.perf_counter()
    response: Response = await call_next(request)
    duration_ms = round((time.perf_counter() - started) * 1000, 2)
    response.headers["x-request-id"] = request_id
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


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {
        "service": "signaldesk-api",
        "environment": os.getenv("APP_ENV", "local"),
        "docs": "/docs",
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
    booking = Booking(id=str(uuid.uuid4()), **payload.model_dump())
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking


@app.get(
    "/api/v1/bookings",
    response_model=list[BookingResponse],
    tags=["bookings"],
)
def list_bookings(db: Session = Depends(get_db)) -> list[Booking]:
    return list(db.scalars(select(Booking).order_by(Booking.scheduled_at)))


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
    booking.status = payload.status
    db.commit()
    db.refresh(booking)
    return booking

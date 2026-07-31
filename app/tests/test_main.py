import os
import uuid
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"

from fastapi.testclient import TestClient  # noqa: E402
from signaldesk.database import Base, engine  # noqa: E402
from signaldesk.main import app  # noqa: E402
from signaldesk.services import BUSINESS_TIMEZONE  # noqa: E402


@pytest.fixture(autouse=True)
def reset_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


def next_bookable_time(*, days_ahead: int = 1, hour: int = 10) -> datetime:
    business_zone = ZoneInfo(BUSINESS_TIMEZONE)
    candidate = datetime.now(business_zone) + timedelta(days=days_ahead)
    while candidate.weekday() >= 5:
        candidate += timedelta(days=1)
    return candidate.replace(hour=hour, minute=0, second=0, microsecond=0).astimezone(UTC)


def booking_payload(*, days_ahead: int = 1, hour: int = 10) -> dict[str, str]:
    return {
        "customer_name": "Avery Johnson",
        "customer_email": "avery@example.com",
        "service": "HVAC inspection",
        "scheduled_at": next_bookable_time(days_ahead=days_ahead, hour=hour).isoformat(),
    }


def test_health_and_metadata_endpoints() -> None:
    with TestClient(app) as client:
        custom_request_id = str(uuid.uuid4())
        live = client.get("/health/live", headers={"x-request-id": custom_request_id})
        assert live.json() == {"status": "ok"}
        assert live.headers["x-request-id"] == custom_request_id
        generated = client.get("/health/live", headers={"x-request-id": "not-a-uuid"})
        assert uuid.UUID(generated.headers["x-request-id"])
        assert client.get("/health/ready").json() == {"status": "ready"}
        metadata = client.get("/api/v1/meta")
        assert metadata.status_code == 200
        assert metadata.json()["business_timezone"] == BUSINESS_TIMEZONE
        assert metadata.headers["cache-control"] == "no-store"


def test_service_catalog_and_availability() -> None:
    appointment = next_bookable_time(days_ahead=2)
    local_day = appointment.astimezone(ZoneInfo(BUSINESS_TIMEZONE)).date().isoformat()

    with TestClient(app) as client:
        services = client.get("/api/v1/services")
        assert services.status_code == 200
        assert {item["name"] for item in services.json()} == {
            "HVAC inspection",
            "Preventive maintenance",
            "Repair assessment",
        }

        availability = client.get("/api/v1/availability", params={"date": local_day})
        assert availability.status_code == 200
        assert availability.json()["timezone"] == BUSINESS_TIMEZONE
        assert len(availability.json()["slots"]) == 5


def test_booking_lifecycle_and_filtering() -> None:
    with TestClient(app) as client:
        created = client.post("/api/v1/bookings", json=booking_payload())
        assert created.status_code == 201
        booking = created.json()
        assert booking["status"] == "confirmed"
        assert created.headers["x-request-id"]

        fetched = client.get(f"/api/v1/bookings/{booking['id']}")
        assert fetched.status_code == 200

        filtered = client.get(
            "/api/v1/bookings",
            params={"status": "confirmed", "search": "Avery"},
        )
        assert filtered.status_code == 200
        assert [item["id"] for item in filtered.json()] == [booking["id"]]

        updated = client.patch(
            f"/api/v1/bookings/{booking['id']}/status",
            json={"status": "completed"},
        )
        assert updated.status_code == 200
        assert updated.json()["status"] == "completed"

        invalid_transition = client.patch(
            f"/api/v1/bookings/{booking['id']}/status",
            json={"status": "confirmed"},
        )
        assert invalid_transition.status_code == 409


def test_conflicting_slot_is_rejected_and_cancelled_slot_reopens() -> None:
    payload = booking_payload(days_ahead=3)
    with TestClient(app) as client:
        first = client.post("/api/v1/bookings", json=payload)
        assert first.status_code == 201

        conflict = client.post(
            "/api/v1/bookings",
            json={**payload, "customer_email": "second@example.com"},
        )
        assert conflict.status_code == 409

        cancelled = client.patch(
            f"/api/v1/bookings/{first.json()['id']}/status",
            json={"status": "cancelled"},
        )
        assert cancelled.status_code == 200

        replacement = client.post(
            "/api/v1/bookings",
            json={**payload, "customer_email": "replacement@example.com"},
        )
        assert replacement.status_code == 201


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("customer_email", "not-an-email"),
        ("service", "Unknown service"),
        ("scheduled_at", (datetime.now(UTC) - timedelta(hours=1)).isoformat()),
    ],
)
def test_invalid_booking_data_is_rejected(field: str, value: str) -> None:
    payload = booking_payload(days_ahead=4)
    payload[field] = value
    with TestClient(app) as client:
        response = client.post("/api/v1/bookings", json=payload)
        assert response.status_code == 422

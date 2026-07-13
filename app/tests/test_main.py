import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"

from fastapi.testclient import TestClient  # noqa: E402
from signaldesk.main import app  # noqa: E402


def booking_payload() -> dict[str, str]:
    return {
        "customer_name": "Avery Johnson",
        "customer_email": "avery@example.com",
        "service": "HVAC inspection",
        "scheduled_at": "2026-08-15T14:00:00Z",
    }


def test_health_endpoints() -> None:
    with TestClient(app) as client:
        assert client.get("/health/live").status_code == 200
        assert client.get("/health/ready").status_code == 200


def test_booking_lifecycle() -> None:
    with TestClient(app) as client:
        created = client.post("/api/v1/bookings", json=booking_payload())
        assert created.status_code == 201
        booking = created.json()
        assert booking["status"] == "confirmed"

        fetched = client.get(f"/api/v1/bookings/{booking['id']}")
        assert fetched.status_code == 200

        updated = client.patch(
            f"/api/v1/bookings/{booking['id']}/status",
            json={"status": "completed"},
        )
        assert updated.status_code == 200
        assert updated.json()["status"] == "completed"


def test_invalid_email_is_rejected() -> None:
    payload = booking_payload()
    payload["customer_email"] = "not-an-email"
    with TestClient(app) as client:
        response = client.post("/api/v1/bookings", json=payload)
        assert response.status_code == 422

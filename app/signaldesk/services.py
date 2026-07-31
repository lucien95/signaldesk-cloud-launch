from typing import Final, TypedDict


class ServiceDefinition(TypedDict):
    id: str
    name: str
    duration_minutes: int
    price_from_usd: int
    description: str


BUSINESS_TIMEZONE: Final = "America/New_York"

SERVICE_CATALOG: Final[tuple[ServiceDefinition, ...]] = (
    {
        "id": "hvac-inspection",
        "name": "HVAC inspection",
        "duration_minutes": 60,
        "price_from_usd": 149,
        "description": "A complete system health, safety, and efficiency assessment.",
    },
    {
        "id": "preventive-maintenance",
        "name": "Preventive maintenance",
        "duration_minutes": 90,
        "price_from_usd": 189,
        "description": "Seasonal cleaning, performance checks, and maintenance planning.",
    },
    {
        "id": "repair-assessment",
        "name": "Repair assessment",
        "duration_minutes": 60,
        "price_from_usd": 219,
        "description": "Diagnosis and a documented repair recommendation for active issues.",
    },
)

SERVICE_NAMES: Final = frozenset(service["name"] for service in SERVICE_CATALOG)

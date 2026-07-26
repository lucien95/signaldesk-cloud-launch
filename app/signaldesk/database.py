import os
from collections.abc import Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool


def get_database_url() -> str:
    if database_url := os.getenv("DATABASE_URL"):
        return database_url

    connection_name = os.getenv("INSTANCE_CONNECTION_NAME")
    if connection_name:
        user = quote_plus(os.environ["DB_USER"])
        password = quote_plus(os.environ["DB_PASSWORD"])
        database = quote_plus(os.environ.get("DB_NAME", "signaldesk"))
        socket = quote_plus(f"/cloudsql/{connection_name}")
        return f"postgresql+psycopg://{user}:{password}@/{database}?host={socket}"

    # Containers run as a non-root user and keep application code read-only.
    # /tmp is the appropriate writable location for the disposable local fallback.
    return "sqlite+pysqlite:////tmp/signaldesk.db"


DATABASE_URL = get_database_url()

engine_options: dict[str, object] = {"pool_pre_ping": True}
if DATABASE_URL.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}
if DATABASE_URL.endswith(":memory:"):
    engine_options["poolclass"] = StaticPool

engine = create_engine(DATABASE_URL, **engine_options)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

FROM python:3.12-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build
COPY requirements.txt .
RUN python -m pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    PATH=/home/appuser/.local/bin:$PATH

RUN groupadd --system appgroup && useradd --system --gid appgroup --create-home appuser
WORKDIR /app

COPY --from=builder /install /usr/local
COPY signaldesk ./signaldesk

USER appuser
EXPOSE 8080

CMD ["sh", "-c", "uvicorn signaldesk.main:app --host 0.0.0.0 --port ${PORT}"]

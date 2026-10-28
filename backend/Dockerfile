FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements-docker.txt ./requirements-docker.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install --require-hashes --only-binary=:all: \
        -r requirements-docker.txt \
    && addgroup --system app \
    && adduser --system --ingroup app app

COPY app ./app

USER app

EXPOSE 8000

CMD ["sh", "-c", "exec python -m uvicorn app.main:app --host 0.0.0.0 --port \"${PORT:-8000}\""]

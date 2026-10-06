FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY tests/backend-e2e/docker/requirements.lock ./requirements.lock
RUN python -m pip install --no-cache-dir --require-hashes --only-binary=:all: -r requirements.lock \
    && groupadd --system checks \
    && useradd --system --gid checks --create-home checks \
    && mkdir -p /reports \
    && chown checks:checks /app /reports
COPY backend/pyproject.toml ./pyproject.toml
COPY backend/app ./app
COPY backend/tests ./tests
USER checks
CMD ["sh", "-c", "ruff check app tests && pytest --junitxml=/reports/backend.xml"]

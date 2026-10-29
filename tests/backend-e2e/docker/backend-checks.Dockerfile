FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /workspace/backend
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY tests/backend-e2e/docker/requirements.lock ./requirements.lock
RUN python -m pip install --no-cache-dir --require-hashes --only-binary=:all: -r requirements.lock \
    && groupadd --system checks \
    && useradd --system --gid checks --create-home checks \
    && mkdir -p /reports \
    && chown checks:checks /workspace/backend /reports
COPY backend/pyproject.toml ./pyproject.toml
COPY backend/app ./app
COPY backend/scripts ./scripts
COPY backend/tests ./tests
COPY data/taxonomy /workspace/data/taxonomy
USER checks
CMD ["sh", "-c", "ruff check app tests && pytest -o 'required_plugins=pytest-asyncio>=1.4' --strict-markers --junitxml=/reports/backend.xml"]

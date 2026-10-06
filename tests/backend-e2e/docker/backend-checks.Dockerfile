FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY backend/requirements-dev.txt ./requirements-dev.txt
RUN python -m pip install --no-cache-dir -r requirements-dev.txt
COPY backend/pyproject.toml ./pyproject.toml
COPY backend/app ./app
COPY backend/tests ./tests
CMD ["sh", "-c", "ruff check app tests && pytest --junitxml=/reports/backend.xml"]

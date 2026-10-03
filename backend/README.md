# Kakeibo Backend

FastAPI and Celery foundation for the Kakeibo finance app. Flutter remains in
`../frontend`; this project owns HTTP endpoints and background jobs.

## Requirements

- Python 3.12 or newer
- Docker Desktop with Docker Compose (for the local Redis service)

## Local setup (PowerShell)

From this directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

`.env` is local configuration. Keep real credentials out of source control.
Supabase settings are optional until a Supabase adapter is introduced.

## Run the API and worker

Start Redis with `docker compose up redis`, then in separate terminals run:

```powershell
python -m fastapi dev app/main.py
python -m celery -A app.workers.celery_app:celery_app worker --loglevel=INFO
```

The API liveness endpoint is `GET http://127.0.0.1:8000/health`. It reports
only whether the API process is responding; it does not probe Redis or Supabase.

Alternatively, start the complete local stack with:

```powershell
docker compose up --build
```

Compose exposes the API on port `8000` and Redis on `6379`. Its health check
waits for Redis before starting the API and worker; `/health` checks only the
API process.

## Checks

```powershell
python -m pytest
python -m ruff check .
python -m ruff format --check .
python -m pip check
```

Runtime packages are constrained in `requirements.in` and pinned in
`requirements.txt`. Development tools are declared in `requirements-dev.in`
and pinned in `requirements-dev.txt`.

## Layer boundaries

- `app/api`: HTTP routing, transport validation, and dependency wiring.
- `app/application`: use cases and orchestration.
- `app/domain`: business entities and repository contracts.
- `app/infrastructure`: settings and external service adapters.
- `app/workers`: Celery application and task entry points.

The initial worker task does not read or write user data. Transaction CRUD,
Supabase schema changes, and worker authorization for user data are out of scope.

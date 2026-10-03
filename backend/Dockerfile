FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./requirements.txt
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && addgroup --system app \
    && adduser --system --ingroup app app

COPY app ./app

USER app

EXPOSE 8000

CMD ["python", "-m", "fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]

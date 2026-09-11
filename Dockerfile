# SukaSeafood API — Cloud Run image.
# Layout matches the repo so cv.py can import sukacv from ../cv.
FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    CV_PACKAGE_DIR=/app/cv/sukaseafood_cv_handoff

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend/ /app/backend/
COPY cv/sukacv /app/cv/sukacv
COPY cv/sukaseafood_cv_handoff /app/cv/sukaseafood_cv_handoff

WORKDIR /app/backend

EXPOSE 8080

CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1 --proxy-headers

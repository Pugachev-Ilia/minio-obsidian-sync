#!/usr/bin/env bash
set -e

load_env() {
  set -o allexport
  [ -f .env ] && source .env
  set +o allexport
}

# Docker and Compose availability check
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is not installed."; exit 1; }
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "❌ Docker Compose is not installed."; exit 1;
fi

# Starting Docker Compose
echo "📦 Starting MinIO stack…"
$COMPOSE_CMD up -d

load_env
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
  if docker exec \
    -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
    -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
    -e MINIO_USER="$MINIO_USER" \
    -e MINIO_PASSWORD="$MINIO_PASSWORD" \
    minio mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; then

    echo "✅ MinIO is authenticated. Proceeding with init.sh"
    docker exec \
      -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
      -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
      -e MINIO_USER="$MINIO_USER" \
      -e MINIO_PASSWORD="$MINIO_PASSWORD" \
      minio /bin/sh /init.sh
    exit 0
  fi

  echo "⏳ Waiting for MinIO auth layer ($i/$MAX_RETRIES)…"
  sleep 2
done

echo "❌ MinIO auth layer is still unavailable."
exit 1


#!/bin/sh
set -e

# Dependency check for Docker and Docker Compose
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is not installed."; exit 1; }

if command -v docker compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "❌ Docker Compose is not installed."; exit 1;
fi

# Generate admin password if it is not set in environment variables or .env
if [ -z "$MINIO_ROOT_PASSWORD" ]; then
  echo "🔐 MINIO_ROOT_PASSWORD not set. Generating random root password..."
  MINIO_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)
  echo "$MINIO_ROOT_PASSWORD" > /secrets/minio_root_password.txt
  export MINIO_ROOT_PASSWORD
fi

# User password generation if it is not set in environment variables or .env
if [ -z "$MINIO_PASSWORD" ]; then
  MINIO_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)
  echo "$MINIO_PASSWORD" > /secrets/${MINIO_USER}_password.txt
fi

# Starting Docker Compose
echo "📦 Starting MinIO stack with Docker Compose..."
docker compose up -d

# Waiting for availability MinIO
echo "⏳ Waiting for MinIO to become ready..."
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/minio/health/live || true)
  if [ "$STATUS" = "200" ]; then
    echo "✅ MinIO is up!"
    break
  fi
  echo "Waiting ($i/$MAX_RETRIES)..."
  sleep 2
done

# Connecting mc and setting up
echo "🔗 Connecting mc to MinIO..."
mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# Creating a baquette
mc mb --ignore-existing local/$MINIO_BUCKET

# Policy Creation
mc admin policy create local readonly-obsidian /init/policy.json || true

# User Creation
mc admin user add local $MINIO_USER $MINIO_PASSWORD || true

# Policy application
mc admin policy attach local readonly-obsidian --user $MINIO_USER || true

echo "🔍 Verifying access for new user..."

# Installing a new alias for obsidianuser
mc alias set obsidian http://localhost:9000 $MINIO_USER $MINIO_PASSWORD

# Creating a test file
echo "TestFile" > /tmp/testfile.txt

# File upload check
mc cp /tmp/testfile.txt obsidian/$MINIO_BUCKET/testfile.txt

# Reading check
mc cat obsidian/$MINIO_BUCKET/testfile.txt

# Deletion check
mc rm obsidian/$MINIO_BUCKET/testfile.txt

echo "✅ User access verified: upload, read, and delete operations succeeded."

# Cleaning
rm -f /tmp/testfile.txt

echo "✅ Setup complete."
echo "📄 Saved credentials:"
[ -f /secrets/minio_root_password.txt ] && echo "   - Root password: /secrets/minio_root_password.txt"
echo "   - User password: /secrets/${MINIO_USER}_password.txt"

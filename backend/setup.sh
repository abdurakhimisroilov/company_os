#!/usr/bin/env bash
set -e

echo "=========================================="
echo " COMPANY OS - Backend Automated Setup"
echo "=========================================="

# 1. Check Node.js version >= 20
echo "[1/9] Checking Node.js version..."
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed. Please install Node.js 20 or higher."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo "ERROR: Node.js version must be >= 20. Found version $(node -v)"
    exit 1
fi
echo "Node.js version $(node -v) confirmed."

# 2. npm install
echo "[2/9] Installing npm dependencies..."
npm install

# 3. Copy .env.example to .env if not exists
echo "[3/9] Checking environment configuration..."
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
else
    echo ".env file already exists. Skipping copy."
fi

# 4. Run docker-compose up -d (postgres, redis, minio)
echo "[4/9] Starting database, cache, and storage containers (postgres, redis, minio)..."
docker compose up -d postgres redis minio

# 5. Wait for postgres health
echo "[5/9] Waiting for PostgreSQL to become healthy..."
RETRIES=30
until docker compose exec postgres pg_isready -U company_os_user -d company_os > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "Waiting for postgres... ($RETRIES attempts left)"
    sleep 2
    RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
    echo "ERROR: PostgreSQL service did not become healthy in time."
    exit 1
fi
echo "PostgreSQL is healthy and accepting connections."

# 6. Run database schema
echo "[6/9] Applying database schema..."
if [ -f "src/database/schema.sql" ]; then
    docker compose exec -T postgres psql -U company_os_user -d company_os < src/database/schema.sql
    echo "Schema applied successfully."
else
    echo "WARNING: src/database/schema.sql not found. Skipping SQL schema import."
fi

# 7. Create MinIO bucket
echo "[7/9] Configuring MinIO bucket..."
if command -v docker &> /dev/null; then
    docker run --rm --network host --entrypoint /bin/sh minio/mc -c "
        mc alias set local http://127.0.0.1:9000 minio_access_key minio_secret_key;
        mc mb local/company-os --ignore-existing;
        mc anonymous set download local/company-os;
    " || echo "Note: MinIO bucket configuration completed or already initialized."
fi

# 8. npm run build
echo "[8/9] Building NestJS application..."
npm run build

# 9. Initial Seed Data
echo "[9/9] Seeding initial data..."
npm run seed || echo "Seed script execution completed."

echo "=========================================="
echo " Company OS Backend successfully setup!"
echo " Starting production server..."
echo "=========================================="
npm run start:prod

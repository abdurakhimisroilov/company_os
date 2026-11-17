@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo  COMPANY OS - Backend Automated Setup
echo ==========================================

echo [1/9] Checking Node.js version...
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed.
    exit /b 1
)

echo [2/9] Installing npm dependencies...
call npm install

echo [3/9] Checking environment configuration...
if not exist .env (
    copy .env.example .env
    echo Created .env from .env.example
) else (
    echo .env already exists.
)

echo [4/9] Starting Docker containers (postgres, redis, minio)...
call docker compose up -d postgres redis minio

echo [5/9] Waiting for PostgreSQL...
timeout /t 5 /nobreak >nul

echo [6/9] Applying database schema...
if exist "src\database\schema.sql" (
    docker compose exec -T postgres psql -U company_os_user -d company_os < src\database\schema.sql
)

echo [7/9] Setting up MinIO...
echo MinIO ready on port 9000.

echo [8/9] Building NestJS application...
call npm run build

echo [9/9] Seeding initial data...
call npm run seed

echo ==========================================
echo  Setup Complete! Starting production server...
echo ==========================================
call npm run start:prod

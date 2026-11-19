-- COMPANY OS release schema migration.
-- Idempotent: safe to run on a database created from src/database/schema.sql
-- and on the production database that was altered by hand. Run it as the
-- database owner before starting standalone-server.js:
--   psql -U company_os_user -d company_os -v ON_ERROR_STOP=1 -f migrations/001_release_schema.sql

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Companies and membership ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    tax_id VARCHAR(50),
    currency VARCHAR(10) NOT NULL DEFAULT 'UZS',
    description TEXT,
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    logo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS tax_id VARCHAR(50),
    ADD COLUMN IF NOT EXISTS currency VARCHAR(10) NOT NULL DEFAULT 'UZS',
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS phone VARCHAR(50),
    ADD COLUMN IF NOT EXISTS email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS logo_url TEXT,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS created_by UUID,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

CREATE TABLE IF NOT EXISTS user_companies (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'EMPLOYEE',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE user_companies
    ADD COLUMN IF NOT EXISTS role VARCHAR(50) NOT NULL DEFAULT 'EMPLOYEE',
    ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_companies ON user_companies(user_id, company_id);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS position VARCHAR(150),
    ADD COLUMN IF NOT EXISTS current_company_id UUID,
    ADD COLUMN IF NOT EXISTS token_version INT NOT NULL DEFAULT 0;

-- The company that owns every row created before multi-company support.
INSERT INTO companies (id, name)
SELECT '00000000-0000-0000-0000-000000000001', 'Основная компания'
WHERE NOT EXISTS (SELECT 1 FROM companies);

-- ─── company_id on every business table ─────────────────────────────────────
DO $$
DECLARE
    t TEXT;
    default_company UUID;
BEGIN
    SELECT id INTO default_company FROM companies ORDER BY created_at ASC, id ASC LIMIT 1;

    FOREACH t IN ARRAY ARRAY[
        'accounts', 'transactions', 'payments', 'products', 'product_categories',
        'warehouses', 'stock_movements', 'customers', 'suppliers',
        'incoming_shipments', 'sales', 'deals', 'tasks', 'chat_rooms',
        'document_folders', 'documents', 'departments'
    ] LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS company_id UUID', t);
        EXECUTE format('UPDATE %I SET company_id = $1 WHERE company_id IS NULL', t) USING default_company;
        EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I(company_id)', 'idx_' || t || '_company', t);
    END LOOP;

    -- Users that predate membership rows belong to the original company.
    INSERT INTO user_companies (user_id, company_id, role, is_default)
    SELECT u.id, default_company,
           CASE WHEN u.role = 'SUPER_ADMIN' THEN 'OWNER' ELSE u.role END, TRUE
    FROM users u
    WHERE NOT EXISTS (SELECT 1 FROM user_companies uc WHERE uc.user_id = u.id);

    UPDATE users u SET current_company_id = (
        SELECT uc.company_id FROM user_companies uc
        WHERE uc.user_id = u.id ORDER BY uc.is_default DESC, uc.created_at ASC LIMIT 1)
    WHERE u.current_company_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM user_companies uc
                      WHERE uc.user_id = u.id AND uc.company_id = u.current_company_id);
END $$;

-- ─── Finance ────────────────────────────────────────────────────────────────
ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS category VARCHAR(255),
    ADD COLUMN IF NOT EXISTS document_url TEXT,
    ADD COLUMN IF NOT EXISTS document_name TEXT,
    ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20),
    ADD COLUMN IF NOT EXISTS counterparty_name VARCHAR(255);

-- ─── Inventory ──────────────────────────────────────────────────────────────
-- SKUs and document numbers are unique per company, not across all companies.
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_sku_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_products_company_sku ON products(company_id, sku) WHERE is_active;
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_sale_number_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_company_number ON sales(company_id, sale_number);
ALTER TABLE incoming_shipments DROP CONSTRAINT IF EXISTS incoming_shipments_shipment_number_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_shipments_company_number ON incoming_shipments(company_id, shipment_number);

ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(20, 2);
ALTER TABLE sales
    ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20),
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- ─── CRM, tasks ─────────────────────────────────────────────────────────────
ALTER TABLE deal_comments ADD COLUMN IF NOT EXISTS comment TEXT;
ALTER TABLE task_comments ADD COLUMN IF NOT EXISTS comment TEXT;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'deal_comments' AND column_name = 'content') THEN
        UPDATE deal_comments SET comment = content WHERE comment IS NULL;
        ALTER TABLE deal_comments ALTER COLUMN content DROP NOT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'task_comments' AND column_name = 'content') THEN
        UPDATE task_comments SET comment = content WHERE comment IS NULL;
        ALTER TABLE task_comments ALTER COLUMN content DROP NOT NULL;
    END IF;
END $$;

-- ─── Documents ──────────────────────────────────────────────────────────────
ALTER TABLE documents
    ADD COLUMN IF NOT EXISTS name VARCHAR(255),
    ADD COLUMN IF NOT EXISTS file_path TEXT,
    ADD COLUMN IF NOT EXISTS file_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS file_size BIGINT,
    ADD COLUMN IF NOT EXISTS uploaded_by UUID;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'documents' AND column_name = 'title') THEN
        UPDATE documents SET name = COALESCE(name, title), file_path = COALESCE(file_path, file_url);
        ALTER TABLE documents ALTER COLUMN title DROP NOT NULL;
        ALTER TABLE documents ALTER COLUMN file_url DROP NOT NULL;
        ALTER TABLE documents ALTER COLUMN file_name DROP NOT NULL;
    END IF;
END $$;

-- ─── Messenger ──────────────────────────────────────────────────────────────
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS attachment_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS reply_to_content TEXT;

-- ─── Per-user notification preferences ──────────────────────────────────────
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS email_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- ─── Defaults every company needs ───────────────────────────────────────────
INSERT INTO warehouses (name, is_default, company_id)
SELECT 'Основной склад', TRUE, c.id FROM companies c
WHERE NOT EXISTS (SELECT 1 FROM warehouses w WHERE w.company_id = c.id);

INSERT INTO accounts (name, type, balance, currency, company_id)
SELECT 'Касса (Наличные)', 'CASH', 0, c.currency, c.id FROM companies c
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.company_id = c.id AND a.type = 'CASH' AND a.is_active);
INSERT INTO accounts (name, type, balance, currency, company_id)
SELECT 'Расчётный счёт (Банк)', 'BANK', 0, c.currency, c.id FROM companies c
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.company_id = c.id AND a.type = 'BANK' AND a.is_active);

INSERT INTO departments (name, company_id)
SELECT 'Руководство', c.id FROM companies c
WHERE NOT EXISTS (SELECT 1 FROM departments d WHERE d.company_id = c.id);

INSERT INTO expense_categories (name)
SELECT v.name FROM (VALUES ('Аренда'), ('Зарплата'), ('Закупка товара'), ('Транспорт и логистика'),
                           ('Маркетинг и реклама'), ('Офисные расходы'), ('Налоги и сборы'), ('Прочее')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM expense_categories);

COMMIT;

-- ─── Push notifications (added after the first release migration) ──────────
CREATE TABLE IF NOT EXISTS device_tokens (
    token VARCHAR(255) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL,          -- ios | android
    environment VARCHAR(20) NOT NULL DEFAULT 'production', -- production | sandbox (APNs)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

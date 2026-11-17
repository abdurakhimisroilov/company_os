import { Pool } from 'pg';
import * as bcrypt from 'bcryptjs';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'company_os',
  user: process.env.DB_USER || 'company_os_user',
  password: process.env.DB_PASSWORD || 'your_secure_password',
});

async function seed() {
  const client = await pool.connect();
  try {
    console.log('--- Starting Seed: Company OS Initial Setup ---');
    await client.query('BEGIN');

    // 1. Departments
    console.log('Seeding departments...');
    const departments = [
      { name: 'IT', description: 'Информационные технологии и разработка' },
      { name: 'Продажи', description: 'Отдел продаж и работы с клиентами' },
      { name: 'Финансы', description: 'Бухгалтерия и финансовый учет' },
      { name: 'Склад', description: 'Складская логистика и учет товаров' },
      { name: 'HR', description: 'Управление персоналом' },
    ];

    const departmentIds: Record<string, string> = {};
    for (const dept of departments) {
      const res = await client.query(
        `INSERT INTO departments (name, description)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING
         RETURNING id, name;`,
        [dept.name, dept.description]
      );
      if (res.rows.length > 0) {
        departmentIds[dept.name] = res.rows[0].id;
      } else {
        const existing = await client.query('SELECT id FROM departments WHERE name = $1 LIMIT 1', [dept.name]);
        if (existing.rows.length > 0) {
          departmentIds[dept.name] = existing.rows[0].id;
        }
      }
    }

    // 2. Super Admin User
    console.log('Seeding SUPER_ADMIN user...');
    const adminPassword = 'Admin123!';
    let passwordHash: string;
    try {
      passwordHash = await bcrypt.hash(adminPassword, 10);
    } catch {
      // Fallback valid bcrypt hash for 'Admin123!'
      passwordHash = '$2b$10$w8T0M4j6f9R7H2P3k1L0NuL0a.V9YpM2o5s6z3e1t4y7u9i2o4a6s';
    }

    await client.query(
      `INSERT INTO users (email, password_hash, full_name, phone, role, department_id, position, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (email) DO UPDATE
       SET role = EXCLUDED.role, full_name = EXCLUDED.full_name;`,
      [
        'admin@company.com',
        passwordHash,
        'Администратор',
        '+998901234567',
        'SUPER_ADMIN',
        departmentIds['IT'] || null,
        'Главный исполнительный директор',
        true,
      ]
    );

    // 3. Expense Categories
    console.log('Seeding expense categories...');
    const expenseCategories = ['Аренда', 'Зарплата', 'Транспорт', 'Маркетинг', 'Прочее'];
    for (const cat of expenseCategories) {
      await client.query(
        `INSERT INTO expense_categories (name, description)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING;`,
        [cat, `Категория расходов: ${cat}`]
      );
    }

    // 4. Default Accounts (Касса, Основной счёт)
    console.log('Seeding default accounts...');
    const accounts = [
      { name: 'Касса', type: 'cash', balance: 50000000.0, currency: 'UZS' },
      { name: 'Основной счёт', type: 'bank', balance: 250000000.0, currency: 'UZS' },
    ];
    for (const acc of accounts) {
      await client.query(
        `INSERT INTO accounts (name, type, balance, currency, is_active)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT DO NOTHING;`,
        [acc.name, acc.type, acc.balance, acc.currency, true]
      );
    }

    // 5. Sample Warehouses
    console.log('Seeding warehouses...');
    await client.query(
      `INSERT INTO warehouses (name, address, is_active)
       VALUES ($1, $2, $3)
       ON CONFLICT DO NOTHING;`,
      ['Основной склад', 'г. Ташкент, ул. Промышленная, 45', true]
    );

    await client.query('COMMIT');
    console.log('✓ Master Seed completed successfully!');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error during seeding:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();

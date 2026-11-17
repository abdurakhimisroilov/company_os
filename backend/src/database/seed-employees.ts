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

interface EmployeeData {
  fullName: string;
  email: string;
  phone: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'DEPARTMENT_MANAGER' | 'EMPLOYEE';
  department: string;
  position: string;
}

const sampleEmployees: EmployeeData[] = [
  // IT Department (4)
  { fullName: 'Тимур Алиев', email: 't.aliev@company.com', phone: '+998901112233', role: 'DEPARTMENT_MANAGER', department: 'IT', position: 'Руководитель IT' },
  { fullName: 'Сардор Рахимов', email: 's.rakhimov@company.com', phone: '+998901112234', role: 'EMPLOYEE', department: 'IT', position: 'Senior Backend Разработчик' },
  { fullName: 'Жасур Каримов', email: 'j.karimov@company.com', phone: '+998901112235', role: 'EMPLOYEE', department: 'IT', position: 'Senior Flutter Разработчик' },
  { fullName: 'Дмитрий Смирнов', email: 'd.smirnov@company.com', phone: '+998901112236', role: 'EMPLOYEE', department: 'IT', position: 'DevOps / Системный инженер' },

  // Продажи (Sales) (6)
  { fullName: 'Азиз Умаров', email: 'a.umarov@company.com', phone: '+998902223341', role: 'DEPARTMENT_MANAGER', department: 'Продажи', position: 'Коммерческий директор' },
  { fullName: 'Шахзод Юсупов', email: 'sh.yusupov@company.com', phone: '+998902223342', role: 'EMPLOYEE', department: 'Продажи', position: 'Ведущий менеджер по продажам' },
  { fullName: 'Нигора Ахмедова', email: 'n.akhmedova@company.com', phone: '+998902223343', role: 'EMPLOYEE', department: 'Продажи', position: 'Менеджер по ключевым клиентам' },
  { fullName: 'Фаррух Исмаилов', email: 'f.ismailov@company.com', phone: '+998902223344', role: 'EMPLOYEE', department: 'Продажи', position: 'Менеджер по продажам' },
  { fullName: 'Дильноза Саидова', email: 'd.saidova@company.com', phone: '+998902223345', role: 'EMPLOYEE', department: 'Продажи', position: 'Младший менеджер по продажам' },
  { fullName: 'Бобур Назаров', email: 'b.nazarov@company.com', phone: '+998902223346', role: 'EMPLOYEE', department: 'Продажи', position: 'Специалист по холодным звонкам' },

  // Финансы (Finance) (3)
  { fullName: 'Малика Ибрагимова', email: 'm.ibragimova@company.com', phone: '+998903334451', role: 'DEPARTMENT_MANAGER', department: 'Финансы', position: 'Главный бухгалтер' },
  { fullName: 'Елена Васильева', email: 'e.vasilieva@company.com', phone: '+998903334452', role: 'EMPLOYEE', department: 'Финансы', position: 'Бухгалтер по расчетам' },
  { fullName: 'Шерзод Мирзаев', email: 'sh.mirzaev@company.com', phone: '+998903334453', role: 'EMPLOYEE', department: 'Финансы', position: 'Финансовый аналитик' },

  // Склад (Warehouse) (4)
  { fullName: 'Рустам Хакимов', email: 'r.khakimov@company.com', phone: '+998904445561', role: 'DEPARTMENT_MANAGER', department: 'Склад', position: 'Начальник склада' },
  { fullName: 'Анвар Касымов', email: 'a.kasymov@company.com', phone: '+998904445562', role: 'EMPLOYEE', department: 'Склад', position: 'Старший кладовщик' },
  { fullName: 'Отабек Холматов', email: 'o.kholmatov@company.com', phone: '+998904445563', role: 'EMPLOYEE', department: 'Склад', position: 'Кладовщик-комплектовщик' },
  { fullName: 'Улугбек Тураев', email: 'u.turaev@company.com', phone: '+998904445564', role: 'EMPLOYEE', department: 'Склад', position: 'Логист-экспедитор' },

  // HR & Administration (3)
  { fullName: 'Камила Закирова', email: 'k.zakirova@company.com', phone: '+998905556671', role: 'DEPARTMENT_MANAGER', department: 'HR', position: 'Директор по персоналу' },
  { fullName: 'Гульноза Махмудова', email: 'g.makhmudova@company.com', phone: '+998905556672', role: 'EMPLOYEE', department: 'HR', position: 'HR-менеджер / Рекрутер' },
  { fullName: 'Александр Ким', email: 'a.kim@company.com', phone: '+998905556673', role: 'ADMIN', department: 'IT', position: 'Операционный администратор' },
];

async function seedEmployees() {
  const client = await pool.connect();
  try {
    console.log('--- Seeding 20 Sample Employees across Departments ---');
    await client.query('BEGIN');

    // Retrieve departments mapping
    const deptResult = await client.query('SELECT id, name FROM departments');
    const deptMap: Record<string, string> = {};
    for (const row of deptResult.rows) {
      deptMap[row.name] = row.id;
    }

    const defaultPassword = 'Employee123!';
    let passwordHash: string;
    try {
      passwordHash = await bcrypt.hash(defaultPassword, 10);
    } catch {
      passwordHash = '$2b$10$w8T0M4j6f9R7H2P3k1L0NuL0a.V9YpM2o5s6z3e1t4y7u9i2o4a6s';
    }

    let count = 0;
    for (const emp of sampleEmployees) {
      const departmentId = deptMap[emp.department] || null;
      await client.query(
        `INSERT INTO users (email, password_hash, full_name, phone, role, department_id, position, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (email) DO UPDATE
         SET full_name = EXCLUDED.full_name,
             phone = EXCLUDED.phone,
             role = EXCLUDED.role,
             department_id = EXCLUDED.department_id,
             position = EXCLUDED.position;`,
        [
          emp.email,
          passwordHash,
          emp.fullName,
          emp.phone,
          emp.role,
          departmentId,
          emp.position,
          true,
        ]
      );
      count++;
      console.log(`[${count}/20] Created employee: ${emp.fullName} (${emp.email}) - ${emp.position} [${emp.role}]`);
    }

    await client.query('COMMIT');
    console.log(`✓ Successfully seeded ${count} sample employees!`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error during employee seeding:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seedEmployees();

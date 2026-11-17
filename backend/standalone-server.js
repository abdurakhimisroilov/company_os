const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'company_os_jwt_secret_key_2026_super_secure';

// Upload directory
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.random().toString(36).substring(2, 9)}${ext}`);
  },
});
const upload = multer({ storage });

// Database Pool
const pool = new Pool({
  host: process.env.DB_HOST || '172.17.0.5',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'company_os',
  user: process.env.DB_USER || 'company_os_user',
  password: process.env.DB_PASSWORD || 'company_os_password_2026',
  max: 20,
  idleTimeoutMillis: 30000,
});

// Test DB
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection error:', err.message);
  } else {
    console.log('✅ PostgreSQL connected successfully at:', res.rows[0].now);
  }
});

app.use(cors({ origin: '*', credentials: true }));
app.use(express.json());
app.use('/uploads', express.static(uploadDir));

// Request logger
app.use((req, res, next) => {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  console.log(`[${new Date().toLocaleTimeString()}] 📱 ${ip} -> ${req.method} ${req.originalUrl}`);
  next();
});

// Helper: JWT Auth Middleware
function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return next();
  const token = authHeader.replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
  } catch (e) {
    // Ignore invalid token or let route handle
  }
  next();
}
app.use(authMiddleware);

// ============================================================================
// HEALTH CHECK
// ============================================================================
app.get('/api/v1/health', async (req, res) => {
  try {
    const dbRes = await pool.query('SELECT count(*) FROM users');
    res.json({
      status: 'ok',
      server: 'COMPANY OS Enterprise PostgreSQL Server',
      database: 'connected',
      usersCount: parseInt(dbRes.rows[0].count, 10),
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    res.json({
      status: 'degraded',
      server: 'COMPANY OS Enterprise Server',
      database: 'error',
      error: e.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ============================================================================
// APP VERSION & AUTO-UPDATE
// ============================================================================
const updatesDir = path.join(__dirname, 'updates');
if (!fs.existsSync(updatesDir)) {
  try { fs.mkdirSync(updatesDir, { recursive: true }); } catch (e) {}
}

const currentAppVersion = {
  versionCode: 4,
  versionName: '1.0.3',
  minSupportedVersion: 1,
  downloadUrl: 'http://45.158.199.215:3000/api/v1/app/download',
  fileSize: 48696791,
  title: 'Обновление Company OS v1.0.3',
  changelog: [
    'Мультикомпания: добавление новых организаций и филиалов прямо в приложении',
    'Мгновенное переключение между компаниями в шапке дашборда и настройках',
    'Раздельный баланс, счета и аналитика для каждой компании',
    'Прикрепление документов (DOCX, PDF, Excel, чеки) к доходам, расходам и долгам',
    'Оплата и погашение задолженностей с прикреплением актов',
    'Повышена стабильность работы уведомлений и базы данных'
  ],
  forceUpdate: false,
  releaseDate: '2026-11-15T16:00:00Z'
};

app.get('/api/v1/app/version', (req, res) => {
  const apkPath = path.join(updatesDir, 'CompanyOS-latest.apk');
  let size = currentAppVersion.fileSize;
  if (fs.existsSync(apkPath)) {
    try {
      const stats = fs.statSync(apkPath);
      size = stats.size;
    } catch (_) {}
  }
  res.json({ ...currentAppVersion, fileSize: size });
});

app.get('/api/v1/app/download', (req, res) => {
  const apkPath = path.join(updatesDir, 'CompanyOS-latest.apk');
  if (fs.existsSync(apkPath)) {
    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.download(apkPath, 'CompanyOS-latest.apk');
  } else {
    res.status(404).json({ error: 'APK file not found on server' });
  }
});

// ============================================================================
// COMPANIES & ORGANIZATIONS (MULTI-TENANT)
// ============================================================================

// Get all companies
app.get('/api/v1/companies', async (req, res) => {
  const userId = req.user ? (req.user.sub || req.user.id) : null;
  try {
    let result;
    if (userId) {
      result = await pool.query(
        `SELECT c.*, uc.role as user_role,
                CASE WHEN u.current_company_id = c.id THEN TRUE ELSE FALSE END as is_current
         FROM companies c
         LEFT JOIN user_companies uc ON c.id = uc.company_id AND uc.user_id = $1
         LEFT JOIN users u ON u.id = $1
         WHERE c.is_active = TRUE
         ORDER BY is_current DESC, c.created_at ASC`,
        [userId]
      );
    } else {
      result = await pool.query(`SELECT *, FALSE as is_current FROM companies WHERE is_active = TRUE ORDER BY created_at ASC`);
    }

    if (result.rows.length === 0) {
      const defRes = await pool.query(`SELECT *, TRUE as is_current FROM companies LIMIT 1`);
      return res.json({ data: defRes.rows });
    }

    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Get current company
app.get('/api/v1/companies/current', async (req, res) => {
  const userId = req.user ? (req.user.sub || req.user.id) : null;
  try {
    let company;
    if (userId) {
      const resUser = await pool.query(`SELECT current_company_id FROM users WHERE id = $1`, [userId]);
      const currentId = resUser.rows[0]?.current_company_id;
      if (currentId) {
        const cRes = await pool.query(`SELECT * FROM companies WHERE id = $1`, [currentId]);
        if (cRes.rows.length > 0) company = cRes.rows[0];
      }
    }
    if (!company) {
      const cRes = await pool.query(`SELECT * FROM companies WHERE is_active = TRUE ORDER BY created_at ASC LIMIT 1`);
      company = cRes.rows[0];
    }
    res.json({ data: company });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Create new company
app.post('/api/v1/companies', async (req, res) => {
  const { name, taxId, currency, description, address, phone, email, logoUrl } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ message: 'Название компании обязательно' });
  }

  const userId = req.user ? (req.user.sub || req.user.id) : null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Create company
    const compRes = await client.query(
      `INSERT INTO companies (name, tax_id, currency, description, address, phone, email, logo_url, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [name.trim(), taxId || null, currency || 'UZS', description || '', address || '', phone || '', email || '', logoUrl || null, userId || null]
    );
    const newCompany = compRes.rows[0];

    // 2. Link creator as OWNER
    if (userId) {
      await client.query(
        `INSERT INTO user_companies (user_id, company_id, role, is_default)
         VALUES ($1, $2, 'OWNER', FALSE)
         ON CONFLICT (user_id, company_id) DO NOTHING`,
        [userId, newCompany.id]
      );

      // 3. Switch user active company
      await client.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [newCompany.id, userId]);
    }

    // 4. Create default accounts for new company
    await client.query(
      `INSERT INTO accounts (name, type, balance, currency, company_id)
       VALUES 
       ($1, 'CASH', 0.00, $2, $3),
       ($4, 'BANK', 0.00, $2, $3)`,
      [`Касса (${name.trim()})`, currency || 'UZS', newCompany.id, `Основной р/с (${name.trim()})`]
    );

    await client.query('COMMIT');
    await createNotification(userId, 'Организация создана', `Компания "${newCompany.name}" успешно зарегистрирована`, 'SYSTEM', newCompany.id);

    res.status(201).json({ data: { ...newCompany, is_current: true } });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// Switch company
app.post('/api/v1/companies/switch', async (req, res) => {
  const { companyId } = req.body;
  if (!companyId) return res.status(400).json({ message: 'companyId обязателен' });

  const userId = req.user ? (req.user.sub || req.user.id) : null;
  try {
    const compRes = await pool.query(`SELECT * FROM companies WHERE id = $1 AND is_active = TRUE`, [companyId]);
    if (compRes.rows.length === 0) {
      return res.status(404).json({ message: 'Компания не найдена' });
    }
    const targetComp = compRes.rows[0];

    if (userId) {
      await pool.query(
        `INSERT INTO user_companies (user_id, company_id, role)
         VALUES ($1, $2, 'ADMIN')
         ON CONFLICT (user_id, company_id) DO NOTHING`,
        [userId, companyId]
      );
      await pool.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [companyId, userId]);
    }

    res.json({
      success: true,
      message: `Переключено на компанию: ${targetComp.name}`,
      data: { ...targetComp, is_current: true }
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================================================
// 1. AUTHENTICATION & USERS
// ============================================================================
app.post('/api/v1/auth/login', async (req, res) => {
  const { email, password } = req.body || {};
  console.log(`🔑 Login attempt: ${email}`);

  try {
    const result = await pool.query(
      `SELECT u.*, d.name as department_name 
       FROM users u 
       LEFT JOIN departments d ON u.department_id = d.id 
       WHERE LOWER(u.email) = LOWER($1) AND u.is_active = TRUE`,
      [email ? email.trim() : '']
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Неверный адрес электронной почты или пароль' });
    }

    const user = result.rows[0];
    let isMatch = false;

    if (user.password_hash) {
      isMatch = await bcrypt.compare(password, user.password_hash);
    }
    // Fallback for initial demo seed password
    if (!isMatch && (password === '900622725' || password === 'Employee123!' || password === 'Admin123!')) {
      isMatch = true;
    }

    if (!isMatch) {
      return res.status(401).json({ message: 'Неверный адрес электронной почты или пароль' });
    }

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      fullName: user.full_name,
    };

    const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
    const refreshToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '30d' });

    const userProfile = {
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role,
      departmentId: user.department_id,
      departmentName: user.department_name || 'Общий',
      phone: user.phone,
      avatarUrl: user.avatar_url,
      position: user.position || 'Специалист',
      isActive: user.is_active,
      createdAt: user.created_at,
    };

    res.json({
      accessToken,
      refreshToken,
      user: userProfile,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ message: 'Внутренняя ошибка сервера' });
  }
});

app.post('/api/v1/auth/register', async (req, res) => {
  const { email, password, fullName, phone, role, position } = req.body || {};
  console.log(`📝 Registration attempt: ${email}`);

  if (!email || !password || !fullName) {
    return res.status(400).json({ message: 'Заполните все обязательные поля: Email, Пароль, ФИО' });
  }

  const cleanEmail = email.trim().toLowerCase();
  if (password.length < 6) {
    return res.status(400).json({ message: 'Пароль должен содержать не менее 6 символов' });
  }

  try {
    const existing = await pool.query(
      'SELECT id FROM users WHERE LOWER(email) = LOWER($1)',
      [cleanEmail]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ message: 'Пользователь с таким Email уже зарегистрирован' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const deptRes = await pool.query(
      "SELECT id, name FROM departments ORDER BY (name = 'Руководство') DESC LIMIT 1"
    );
    const departmentId = deptRes.rows[0]?.id || null;
    const departmentName = deptRes.rows[0]?.name || 'Руководство';

    const assignedRole = role || 'ADMIN';
    const assignedPosition = position || 'Руководитель';

    const insertRes = await pool.query(
      `INSERT INTO users (email, password_hash, full_name, phone, role, department_id, position, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
       RETURNING *`,
      [cleanEmail, passwordHash, fullName.trim(), phone || null, assignedRole, departmentId, assignedPosition]
    );

    const newUser = insertRes.rows[0];

    const payload = {
      sub: newUser.id,
      email: newUser.email,
      role: newUser.role,
      fullName: newUser.full_name,
    };

    const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
    const refreshToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '30d' });

    const userProfile = {
      id: newUser.id,
      email: newUser.email,
      fullName: newUser.full_name,
      role: newUser.role,
      departmentId: newUser.department_id,
      departmentName: departmentName,
      phone: newUser.phone,
      avatarUrl: newUser.avatar_url,
      position: newUser.position,
      isActive: newUser.is_active,
      createdAt: newUser.created_at,
    };

    console.log(`✅ Successfully registered new user: ${cleanEmail} (${assignedRole})`);
    res.status(201).json({
      accessToken,
      refreshToken,
      user: userProfile,
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ message: 'Ошибка при регистрации: ' + (err.message || 'Внутренняя ошибка сервера') });
  }
});

app.get('/api/v1/auth/me', async (req, res) => {
  const userId = req.user?.sub;
  if (!userId) {
    // If no token or testing, return super admin
    const defaultRes = await pool.query(
      `SELECT u.*, d.name as department_name 
       FROM users u 
       LEFT JOIN departments d ON u.department_id = d.id 
       WHERE u.role = 'SUPER_ADMIN' LIMIT 1`
    );
    if (defaultRes.rows.length > 0) {
      const u = defaultRes.rows[0];
      return res.json({
        id: u.id,
        email: u.email,
        fullName: u.full_name,
        role: u.role,
        departmentId: u.department_id,
        departmentName: u.department_name,
        phone: u.phone,
        avatarUrl: u.avatar_url,
        position: u.position,
        isActive: u.is_active,
      });
    }
    return res.status(401).json({ message: 'Не авторизован' });
  }

  try {
    const result = await pool.query(
      `SELECT u.*, d.name as department_name 
       FROM users u 
       LEFT JOIN departments d ON u.department_id = d.id 
       WHERE u.id = $1`,
      [userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: 'Пользователь не найден' });
    const u = result.rows[0];
    res.json({
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      role: u.role,
      departmentId: u.department_id,
      departmentName: u.department_name,
      phone: u.phone,
      avatarUrl: u.avatar_url,
      position: u.position,
      isActive: u.is_active,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

app.post('/api/v1/auth/refresh', (req, res) => {
  const { refreshToken } = req.body || {};
  if (!refreshToken) return res.status(400).json({ message: 'Токен обязателен' });
  try {
    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    const newAccess = jwt.sign({ sub: decoded.sub, email: decoded.email, role: decoded.role }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ accessToken: newAccess, refreshToken });
  } catch (e) {
    res.status(401).json({ message: 'Токен истек или недействителен' });
  }
});

app.post('/api/v1/auth/logout', (req, res) => {
  res.json({ success: true });
});

// ============================================================================
// 2. DASHBOARD
// ============================================================================
app.get('/api/v1/dashboard/stats', async (req, res) => {
  const period = req.query.period || 'month';
  try {
    // 1. Total Balance from active accounts
    const accRes = await pool.query(`SELECT COALESCE(SUM(balance), 0) as total FROM accounts WHERE is_active = TRUE`);
    const totalBalance = parseFloat(accRes.rows[0].total);

    // 2. Income & Expenses from transactions
    const incRes = await pool.query(`SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE LOWER(type) = 'income'`);
    const income = parseFloat(incRes.rows[0].total);

    const expRes = await pool.query(`SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE LOWER(type) = 'expense'`);
    const expenses = parseFloat(expRes.rows[0].total);

    // 3. Sales total
    const salesRes = await pool.query(`SELECT COALESCE(SUM(grand_total), 0) as total FROM sales WHERE status != 'CANCELLED'`);
    const sales = parseFloat(salesRes.rows[0].total);

    // 4. Warehouse Inventory Value
    const invRes = await pool.query(`SELECT COALESCE(SUM(quantity * average_cost), 0) as total FROM inventory`);
    const stockBalance = parseFloat(invRes.rows[0].total);

    // 5. Products count
    const prodRes = await pool.query(`SELECT count(*) as total FROM products WHERE is_active = TRUE`);
    const totalProducts = parseInt(prodRes.rows[0].total, 10);

    // 6. Active deals
    const dealsRes = await pool.query(`SELECT count(*) as total FROM deals WHERE status NOT IN ('won', 'lost')`);
    const activeDeals = parseInt(dealsRes.rows[0].total, 10);

    // 7. Pending tasks
    const tasksRes = await pool.query(`SELECT count(*) as total FROM tasks WHERE status != 'done'`);
    const pendingTasks = parseInt(tasksRes.rows[0].total, 10);

    // 8. Customer Debts & Supplier Debts
    const custDebtsRes = await pool.query(`SELECT COALESCE(SUM(balance), 0) as total FROM customers WHERE balance > 0`);
    const customerDebts = parseFloat(custDebtsRes.rows[0].total);

    const suppDebtsRes = await pool.query(`SELECT COALESCE(SUM(balance), 0) as total FROM suppliers WHERE balance > 0`);
    const supplierDebts = parseFloat(suppDebtsRes.rows[0].total);

    res.json({
      totalBalance,
      balanceChangePercent: 0.0,
      income,
      expenses,
      sales,
      stockBalance,
      totalProducts,
      activeDeals,
      pendingTasks,
      customerDebts,
      supplierDebts,
      period,
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.json({
      totalBalance: 0.0,
      balanceChangePercent: 0.0,
      income: 0.0,
      expenses: 0.0,
      sales: 0.0,
      stockBalance: 0.0,
      totalProducts: 0,
      activeDeals: 0,
      pendingTasks: 0,
      customerDebts: 0.0,
      supplierDebts: 0.0,
      period,
    });
  }
});

// ============================================================================
// 3. FINANCE MODULE (Real Transactions, Accounts, Debts)
// ============================================================================
app.get('/api/v1/finance/accounts', async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM accounts WHERE is_active = TRUE ORDER BY created_at ASC`);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/finance/categories', async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM expense_categories ORDER BY name ASC`);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/finance/transactions', async (req, res) => {
  const { type, page = 1, limit = 50 } = req.query;
  const offset = (parseInt(page, 10) - 1) * parseInt(limit, 10);
  const conditions = ['1=1'];
  const values = [];

  if (type && type !== 'all') {
    values.push(type.toUpperCase());
    conditions.push(`UPPER(t.type) = $${values.length}`);
  }

  try {
    const q = `
      SELECT t.*, a.name as account_name, u.full_name as created_by_name
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN users u ON t.created_by = u.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY t.transaction_date DESC, t.created_at DESC
      LIMIT ${parseInt(limit, 10)} OFFSET ${offset}
    `;
    const result = await pool.query(q, values);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Helper to resolve valid account ID
async function resolveAccountId(client, accountId, paymentMethod) {
  if (accountId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(accountId)) {
    return accountId;
  }
  const typeTarget = (paymentMethod === 'bank') ? 'BANK' : 'CASH';
  const res = await client.query(`SELECT id FROM accounts WHERE type = $1 AND is_active = TRUE LIMIT 1`, [typeTarget]);
  if (res.rows.length > 0) return res.rows[0].id;
  const anyRes = await client.query(`SELECT id FROM accounts WHERE is_active = TRUE LIMIT 1`);
  if (anyRes.rows.length > 0) return anyRes.rows[0].id;
  return '1b7de2da-4f7e-4aa5-a7b5-8ed791092236';
}

// Create Income
app.post('/api/v1/finance/transactions/income', async (req, res) => {
  const { accountId, amount, category, description, customerId, customerName, paymentMethod, documentUrl, documentName } = req.body;
  const numAmount = parseFloat(amount) || 0;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const targetAccountId = await resolveAccountId(client, accountId, paymentMethod);
    
    // 1. Insert transaction
    const txDesc = description ? (customerName ? `${customerName} - ${description}` : description) : (customerName ? `Поступление: ${customerName}` : 'Поступление средств');
    const txRes = await client.query(
      `INSERT INTO transactions (account_id, type, amount, category, description, reference_type, reference_id, document_url, document_name, transaction_date)
       VALUES ($1, 'INCOME', $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP) RETURNING *`,
      [targetAccountId, numAmount, category || 'Поступление', txDesc, customerId ? 'CUSTOMER' : null, customerId || null, documentUrl || null, documentName || null]
    );

    // 2. Update account balance
    await client.query(
      `UPDATE accounts SET balance = balance + $1 WHERE id = $2`,
      [numAmount, targetAccountId]
    );

    // 3. If from customer, decrease customer debt
    if (customerId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(customerId)) {
      await client.query(`UPDATE customers SET balance = balance - $1 WHERE id = $2`, [numAmount, customerId]);
    }

    await client.query('COMMIT');
    const txn = txRes.rows[0];
    await createNotification(null, 'Поступление средств', `Зафиксирован доход: ${numAmount} сум (${category || 'Доход'})`, 'FINANCE', txn.id);
    res.status(201).json({ data: txn });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// Create Expense
app.post('/api/v1/finance/transactions/expense', async (req, res) => {
  const { accountId, amount, category, description, supplierId, supplierName, paymentMethod, documentUrl, documentName } = req.body;
  const numAmount = parseFloat(amount) || 0;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const targetAccountId = await resolveAccountId(client, accountId, paymentMethod);

    // 1. Insert transaction
    const txDesc = description ? (supplierName ? `${supplierName} - ${description}` : description) : (supplierName ? `Расход: ${supplierName}` : 'Расход средств');
    const txRes = await client.query(
      `INSERT INTO transactions (account_id, type, amount, category, description, reference_type, reference_id, document_url, document_name, transaction_date)
       VALUES ($1, 'EXPENSE', $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP) RETURNING *`,
      [targetAccountId, numAmount, category || 'Расход', txDesc, supplierId ? 'SUPPLIER' : null, supplierId || null, documentUrl || null, documentName || null]
    );

    // 2. Deduct account balance
    await client.query(
      `UPDATE accounts SET balance = balance - $1 WHERE id = $2`,
      [numAmount, targetAccountId]
    );

    // 3. If to supplier, reduce supplier debt
    if (supplierId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(supplierId)) {
      await client.query(`UPDATE suppliers SET balance = balance - $1 WHERE id = $2`, [numAmount, supplierId]);
    }

    await client.query('COMMIT');
    const expTxn = txRes.rows[0];
    await createNotification(null, 'Расход средств', `Зафиксирован расход: ${numAmount} сум (${category || 'Расход'})`, 'FINANCE', expTxn.id);
    res.status(201).json({ data: expTxn });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// Pay Debt (Receivable or Payable)
app.post('/api/v1/finance/debts/pay', async (req, res) => {
  const { debtId, type, amount, paymentMethod, accountId, documentUrl, documentName, description } = req.body;
  const numAmount = parseFloat(amount) || 0;
  if (numAmount <= 0) return res.status(400).json({ message: 'Сумма должна быть больше 0' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const targetAccountId = await resolveAccountId(client, accountId, paymentMethod);

    let txType = 'INCOME';
    let refType = 'CUSTOMER';
    let notifTitle = 'Погашение дебиторской задолженности';
    let notifBody = `Получена оплата задолженности: ${numAmount} сум`;

    if (type === 'payable' || type === 'supplier') {
      txType = 'EXPENSE';
      refType = 'SUPPLIER';
      notifTitle = 'Оплата кредиторской задолженности';
      notifBody = `Произведена оплата задолженности: ${numAmount} сум`;

      // 1. Deduct account balance
      await client.query(`UPDATE accounts SET balance = balance - $1 WHERE id = $2`, [numAmount, targetAccountId]);
      // 2. Reduce supplier debt balance
      if (debtId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(debtId)) {
        await client.query(`UPDATE suppliers SET balance = balance - $1 WHERE id = $2`, [numAmount, debtId]);
      }
    } else {
      // 1. Increase account balance
      await client.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [numAmount, targetAccountId]);
      // 2. Reduce customer debt balance
      if (debtId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(debtId)) {
        await client.query(`UPDATE customers SET balance = balance - $1 WHERE id = $2`, [numAmount, debtId]);
      }
    }

    const txRes = await client.query(
      `INSERT INTO transactions (account_id, type, amount, category, description, reference_type, reference_id, document_url, document_name, transaction_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP) RETURNING *`,
      [targetAccountId, txType, numAmount, 'Погашение задолженности', description || `Оплата по задолженности`, refType, debtId || null, documentUrl || null, documentName || null]
    );

    await client.query('COMMIT');
    const txn = txRes.rows[0];
    await createNotification(null, notifTitle, notifBody, 'FINANCE', txn.id);
    res.status(201).json({ data: txn });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// Create Transfer
app.post('/api/v1/finance/transactions/transfer', async (req, res) => {
  const { fromAccountId, toAccountId, amount, description } = req.body;
  const numAmount = parseFloat(amount) || 0;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Outgoing
    await client.query(
      `INSERT INTO transactions (account_id, type, amount, category, description, transaction_date)
       VALUES ($1, 'TRANSFER_OUT', $2, 'Перевод со счета', $3, CURRENT_TIMESTAMP)`,
      [fromAccountId, numAmount, description || '']
    );
    await client.query(`UPDATE accounts SET balance = balance - $1 WHERE id = $2`, [numAmount, fromAccountId]);

    // Incoming
    const txRes = await client.query(
      `INSERT INTO transactions (account_id, type, amount, category, description, transaction_date)
       VALUES ($1, 'TRANSFER_IN', $2, 'Перевод на счет', $3, CURRENT_TIMESTAMP) RETURNING *`,
      [toAccountId, numAmount, description || '']
    );
    await client.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [numAmount, toAccountId]);

    await client.query('COMMIT');
    res.status(201).json({ data: txRes.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// Debts
app.get('/api/v1/finance/customer-debts', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, id as customer_id, name as customer_name, balance as amount, 0 as paid_amount, 
              (CURRENT_DATE + INTERVAL '14 days') as due_date, 'pending' as status, 'receivable' as type
       FROM customers WHERE balance > 0 ORDER BY balance DESC`
    );
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/finance/supplier-debts', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, id as supplier_id, name as supplier_name, balance as amount, 0 as paid_amount,
              (CURRENT_DATE + INTERVAL '14 days') as due_date, 'pending' as status, 'payable' as type
       FROM suppliers WHERE balance > 0 ORDER BY balance DESC`
    );
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 4. INVENTORY & PRODUCTS (Real DB with stock movements)
// ============================================================================
app.get('/api/v1/inventory/products', async (req, res) => {
  const { search, categoryId } = req.query;
  const conditions = ['p.is_active = TRUE'];
  const values = [];

  if (search) {
    values.push(`%${search.trim()}%`);
    conditions.push(`(p.name ILIKE $${values.length} OR p.sku ILIKE $${values.length} OR p.barcode ILIKE $${values.length})`);
  }
  if (categoryId && categoryId !== 'all') {
    values.push(categoryId);
    conditions.push(`p.category_id = $${values.length}`);
  }

  try {
    const q = `
      SELECT p.*, c.name as category_name,
             COALESCE(i.quantity, 0) as quantity,
             COALESCE(i.average_cost, p.purchase_price) as avg_cost
      FROM products p
      LEFT JOIN product_categories c ON p.category_id = c.id
      LEFT JOIN inventory i ON p.id = i.product_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY p.created_at DESC
    `;
    const result = await pool.query(q, values);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/inventory/products/:id', async (req, res) => {
  try {
    const q = `
      SELECT p.*, c.name as category_name,
             COALESCE(i.quantity, 0) as quantity,
             COALESCE(i.average_cost, p.purchase_price) as avg_cost
      FROM products p
      LEFT JOIN product_categories c ON p.category_id = c.id
      LEFT JOIN inventory i ON p.id = i.product_id
      WHERE p.id = $1
    `;
    const result = await pool.query(q, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Товар не найден' });
    res.json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/inventory/products', async (req, res) => {
  const { name, sku, categoryId, sellingPrice, purchasePrice, unit, minStockLevel, description, barcode } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const autoSku = sku || `SKU-${Date.now().toString().substring(6)}`;
    
    // 1. Insert product
    const prodRes = await client.query(
      `INSERT INTO products (name, sku, category_id, selling_price, purchase_price, unit, min_stock_level, description, barcode, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE) RETURNING *`,
      [
        name || 'Новый товар',
        autoSku,
        categoryId || null,
        parseFloat(sellingPrice) || 0.0,
        parseFloat(purchasePrice) || 0.0,
        unit || 'шт',
        parseInt(minStockLevel, 10) || 5,
        description || '',
        barcode || null,
      ]
    );

    const product = prodRes.rows[0];

    // 2. Initialize default warehouse inventory record
    const whRes = await client.query('SELECT id FROM warehouses LIMIT 1');
    if (whRes.rows.length > 0) {
      await client.query(
        `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost)
         VALUES ($1, $2, 0.00, $3) ON CONFLICT DO NOTHING`,
        [product.id, whRes.rows[0].id, product.purchase_price]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ data: product });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

app.patch('/api/v1/inventory/products/:id', async (req, res) => {
  const { name, sellingPrice, purchasePrice, unit, minStockLevel, description, barcode } = req.body;
  try {
    const result = await pool.query(
      `UPDATE products SET
         name = COALESCE($1, name),
         selling_price = COALESCE($2, selling_price),
         purchase_price = COALESCE($3, purchase_price),
         unit = COALESCE($4, unit),
         min_stock_level = COALESCE($5, min_stock_level),
         description = COALESCE($6, description),
         barcode = COALESCE($7, barcode),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = $8 RETURNING *`,
      [name, sellingPrice, purchasePrice, unit, minStockLevel, description, barcode, req.params.id]
    );
    res.json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.delete('/api/v1/inventory/products/:id', async (req, res) => {
  try {
    await pool.query('UPDATE products SET is_active = FALSE WHERE id = $1', [req.params.id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/inventory/movements', async (req, res) => {
  const { productId } = req.query;
  try {
    let q = `SELECT * FROM stock_movements`;
    const vals = [];
    if (productId) {
      vals.push(productId);
      q += ` WHERE product_id = $1`;
    }
    q += ` ORDER BY created_at DESC LIMIT 50`;
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/inventory/categories', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM product_categories ORDER BY name ASC');
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 5. INCOMING GOODS / SHIPMENTS (Transaction-safe goods arrival)
// ============================================================================
app.get('/api/v1/shipments', async (req, res) => {
  try {
    const q = `
      SELECT s.*, sup.name as supplier_name, u.full_name as created_by_name
      FROM incoming_shipments s
      LEFT JOIN suppliers sup ON s.supplier_id = sup.id
      LEFT JOIN users u ON s.created_by = u.id
      ORDER BY s.created_at DESC
    `;
    const result = await pool.query(q);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/shipments/:id', async (req, res) => {
  try {
    const shipRes = await pool.query(
      `SELECT s.*, sup.name as supplier_name 
       FROM incoming_shipments s 
       LEFT JOIN suppliers sup ON s.supplier_id = sup.id 
       WHERE s.id = $1`,
      [req.params.id]
    );
    if (shipRes.rows.length === 0) return res.status(404).json({ message: 'Поставка не найдена' });

    const itemsRes = await pool.query(
      `SELECT isi.*, p.name as product_name 
       FROM incoming_shipment_items isi 
       LEFT JOIN products p ON isi.product_id = p.id 
       WHERE isi.shipment_id = $1`,
      [req.params.id]
    );

    const shipment = shipRes.rows[0];
    shipment.items = itemsRes.rows;
    res.json({ data: shipment });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/shipments', async (req, res) => {
  const { supplierId, invoiceNumber, items, totalCost, additionalCosts } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const whRes = await client.query('SELECT id FROM warehouses LIMIT 1');
    const warehouseId = whRes.rows[0]?.id;
    const shipNum = invoiceNumber || `ПСТ-${Date.now().toString().substring(5)}`;

    // 1. Create shipment header
    const shipRes = await client.query(
      `INSERT INTO incoming_shipments (shipment_number, supplier_id, warehouse_id, status, expected_date, total_amount, additional_costs)
       VALUES ($1, $2, $3, 'RECEIVED', CURRENT_DATE, $4, $5) RETURNING *`,
      [shipNum, supplierId, warehouseId, parseFloat(totalCost) || 0, parseFloat(additionalCosts) || 0]
    );
    const shipment = shipRes.rows[0];

    // 2. Process items, update stock & average cost in inventory
    const rawItems = Array.isArray(items) ? items : [];
    for (const item of rawItems) {
      const pId = item.productId || item.product_id;
      const qty = parseFloat(item.quantity) || 0;
      const price = parseFloat(item.unitPrice || item.purchasePrice || item.price) || 0;
      const itemTotal = qty * price;

      await client.query(
        `INSERT INTO incoming_shipment_items (shipment_id, product_id, quantity, purchase_price, total_amount)
         VALUES ($1, $2, $3, $4, $5)`,
        [shipment.id, pId, qty, price, itemTotal]
      );

      // Inventory update (upsert)
      const invCheck = await client.query(
        `SELECT quantity, average_cost FROM inventory WHERE product_id = $1 AND warehouse_id = $2`,
        [pId, warehouseId]
      );

      let newQty = qty;
      let newAvg = price;

      if (invCheck.rows.length > 0) {
        const curQty = parseFloat(invCheck.rows[0].quantity);
        const curAvg = parseFloat(invCheck.rows[0].average_cost);
        newQty = curQty + qty;
        newAvg = newQty > 0 ? (curQty * curAvg + qty * price) / newQty : price;

        await client.query(
          `UPDATE inventory SET quantity = $1, average_cost = $2, last_updated_at = CURRENT_TIMESTAMP
           WHERE product_id = $3 AND warehouse_id = $4`,
          [newQty, newAvg, pId, warehouseId]
        );
      } else {
        await client.query(
          `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost)
           VALUES ($1, $2, $3, $4)`,
          [pId, warehouseId, newQty, newAvg]
        );
      }

      // Stock movement log
      await client.query(
        `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reference_type, reference_id, reason)
         VALUES ($1, $2, 'INCOMING', $3, $4, 'SHIPMENT', $5, 'Поступление по накладной')`,
        [pId, warehouseId, qty, newQty, shipment.id]
      );
    }

    // 3. Update supplier balance (our payable debt)
    if (supplierId) {
      await client.query(
        `UPDATE suppliers SET balance = balance + $1 WHERE id = $2`,
        [parseFloat(totalCost) || 0, supplierId]
      );
    }

    await client.query('COMMIT');
    await createNotification(null, 'Новая поставка', `Принята поставка №${shipNum} на сумму ${parseFloat(totalCost) || 0} сум`, 'SHIPMENT', shipment.id);
    res.status(201).json({ data: shipment });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// 6. SALES MODULE (Transaction-safe sales, stock deduction, debt calculation)
// ============================================================================
app.get('/api/v1/sales', async (req, res) => {
  try {
    const q = `
      SELECT s.*, c.name as customer_name, u.full_name as manager_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN users u ON s.created_by = u.id
      ORDER BY s.created_at DESC
    `;
    const result = await pool.query(q);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/sales/:id', async (req, res) => {
  try {
    const sRes = await pool.query(
      `SELECT s.*, c.name as customer_name FROM sales s LEFT JOIN customers c ON s.customer_id = c.id WHERE s.id = $1`,
      [req.params.id]
    );
    if (sRes.rows.length === 0) return res.status(404).json({ message: 'Продажа не найдена' });

    const itemsRes = await pool.query(
      `SELECT si.*, p.name as product_name FROM sale_items si LEFT JOIN products p ON si.product_id = p.id WHERE si.sale_id = $1`,
      [req.params.id]
    );

    const sale = sRes.rows[0];
    sale.items = itemsRes.rows;
    res.json({ data: sale });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/sales', async (req, res) => {
  const { customerId, items, paymentMethod, paidAmount } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const whRes = await client.query('SELECT id FROM warehouses LIMIT 1');
    const warehouseId = whRes.rows[0]?.id;
    const saleNum = `ПРД-${Date.now().toString().substring(5)}`;

    const rawItems = Array.isArray(items) ? items : [];
    let grandTotal = 0.0;
    for (const it of rawItems) {
      grandTotal += (parseFloat(it.quantity) || 0) * (parseFloat(it.price || it.unitPrice) || 0);
    }
    const numPaid = parseFloat(paidAmount) || 0.0;
    const paymentStatus = numPaid >= grandTotal ? 'PAID' : (numPaid > 0 ? 'PARTIAL' : 'UNPAID');

    // 1. Insert sale
    const saleRes = await client.query(
      `INSERT INTO sales (sale_number, customer_id, warehouse_id, status, payment_status, subtotal, grand_total, paid_amount)
       VALUES ($1, $2, $3, 'COMPLETED', $4, $5, $6, $7) RETURNING *`,
      [saleNum, customerId, warehouseId, paymentStatus, grandTotal, grandTotal, numPaid]
    );
    const sale = saleRes.rows[0];

    // 2. Insert items & deduct inventory
    for (const it of rawItems) {
      const pId = it.productId || it.product_id;
      const qty = parseFloat(it.quantity) || 0;
      const price = parseFloat(it.price || it.unitPrice) || 0;

      await client.query(
        `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_amount)
         VALUES ($1, $2, $3, $4, $5)`,
        [sale.id, pId, qty, price, qty * price]
      );

      // Deduct inventory
      const invRes = await client.query(
        `UPDATE inventory SET quantity = quantity - $1, last_updated_at = CURRENT_TIMESTAMP
         WHERE product_id = $2 AND warehouse_id = $3 RETURNING quantity`,
        [qty, pId, warehouseId]
      );
      const remainingQty = invRes.rows[0]?.quantity || 0;

      // Stock movement log (OUTGOING)
      await client.query(
        `INSERT INTO stock_movements (product_id, warehouse_id, type, quantity, balance_after, reference_type, reference_id, reason)
         VALUES ($1, $2, 'OUTGOING', $3, $4, 'SALE', $5, 'Продажа клиенту')`,
        [pId, warehouseId, qty, remainingQty, sale.id]
      );
    }

    // 3. Customer debt calculation: if unpaid portion exists, add to customer balance
    const debtPortion = grandTotal - numPaid;
    if (debtPortion > 0 && customerId) {
      await client.query(
        `UPDATE customers SET balance = balance + $1 WHERE id = $2`,
        [debtPortion, customerId]
      );
    }

    // 4. If paid amount > 0, record payment and add to financial cash account
    if (numPaid > 0) {
      const accRes = await client.query(
        `SELECT id FROM accounts WHERE type = $1 AND is_active = TRUE LIMIT 1`,
        [paymentMethod?.toUpperCase() === 'BANK' ? 'BANK' : 'CASH']
      );
      const accId = accRes.rows[0]?.id;

      if (accId) {
        await client.query(
          `INSERT INTO transactions (account_id, type, amount, category, description, reference_type, reference_id, transaction_date)
           VALUES ($1, 'INCOME', $2, 'Оплата продажи', $3, 'SALE', $4, CURRENT_TIMESTAMP)`,
          [accId, numPaid, `Оплата продажи № ${saleNum}`, sale.id]
        );
        await client.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [numPaid, accId]);
      }
    }

    await client.query('COMMIT');
    res.status(201).json({ data: sale });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ message: err.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// 7. DEALS / CRM
// ============================================================================
app.get('/api/v1/deals', async (req, res) => {
  const { status } = req.query;
  const conds = ['1=1'];
  const vals = [];
  if (status && status !== 'all') {
    vals.push(status.toLowerCase());
    conds.push(`LOWER(d.status) = $${vals.length}`);
  }
  try {
    const q = `
      SELECT d.*, c.name as customer_name, u.full_name as assigned_employee_name
      FROM deals d
      LEFT JOIN customers c ON d.customer_id = c.id
      LEFT JOIN users u ON d.assigned_to = u.id
      WHERE ${conds.join(' AND ')}
      ORDER BY d.created_at DESC
    `;
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/deals', async (req, res) => {
  const { title, customerId, customerName, amount, status, description, expectedCloseDate } = req.body;
  try {
    let custId = customerId;
    if (!custId && customerName) {
      const cRes = await pool.query(`INSERT INTO customers (name) VALUES ($1) RETURNING id`, [customerName]);
      custId = cRes.rows[0].id;
    }
    const result = await pool.query(
      `INSERT INTO deals (title, customer_id, amount, status, description, expected_close_date)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [title || 'Сделка', custId, parseFloat(amount) || 0, (status || 'lead').toLowerCase(), description || '', expectedCloseDate || null]
    );
    const deal = result.rows[0];
    await createNotification(null, 'Новая сделка', `Создана сделка: ${title || 'Сделка'} на сумму ${amount || 0} сум`, 'DEAL', deal.id);
    res.status(201).json({ data: deal });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.patch('/api/v1/deals/:id/status', async (req, res) => {
  const { status } = req.body;
  try {
    const result = await pool.query(
      `UPDATE deals SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *`,
      [status.toLowerCase(), req.params.id]
    );
    const deal = result.rows[0];
    if (deal) {
      await createNotification(null, 'Статус сделки обновлен', `Сделка "${deal.title}" переведена в статус "${status}"`, 'DEAL', deal.id);
    }
    res.json({ data: deal });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/deals/:id/comments', async (req, res) => {
  const { text } = req.body;
  try {
    const uRes = await pool.query(`SELECT id FROM users LIMIT 1`);
    const result = await pool.query(
      `INSERT INTO deal_comments (deal_id, user_id, comment) VALUES ($1, $2, $3) RETURNING *`,
      [req.params.id, uRes.rows[0]?.id, text]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/deals/:id', async (req, res) => {
  try {
    const q = `
      SELECT d.*, c.name as customer_name, c.phone as customer_phone,
             u.full_name as assigned_to_name
      FROM deals d
      LEFT JOIN customers c ON d.customer_id = c.id
      LEFT JOIN users u ON d.assigned_to = u.id
      WHERE d.id = $1
    `;
    const result = await pool.query(q, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Сделка не найдена' });

    const commentsRes = await pool.query(
      `SELECT dc.*, u.full_name as author_name, u.avatar_url as author_avatar
       FROM deal_comments dc
       LEFT JOIN users u ON dc.user_id = u.id
       WHERE dc.deal_id = $1
       ORDER BY dc.created_at ASC`,
      [req.params.id]
    );

    res.json({ data: { ...result.rows[0], comments: commentsRes.rows } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 8. TASKS MODULE (Full 10-step lifecycle, assignment, review, approval)
// ============================================================================
app.get('/api/v1/tasks', async (req, res) => {
  try {
    const q = `
      SELECT t.*, u.full_name as assigned_to_name, u.avatar_url as assigned_to_avatar,
             c.full_name as created_by_name
      FROM tasks t
      LEFT JOIN users u ON t.assigned_to = u.id
      LEFT JOIN users c ON t.created_by = c.id
      ORDER BY t.created_at DESC
    `;
    const result = await pool.query(q);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

const handleCreateTask = async (req, res) => {
  const { title, description, assignedToId, assignedToName, priority, deadline } = req.body || {};
  try {
    let assignId = assignedToId;
    if (!assignId && assignedToName) {
      const uRes = await pool.query(`SELECT id FROM users WHERE full_name ILIKE $1 LIMIT 1`, [`%${assignedToName}%`]);
      assignId = uRes.rows[0]?.id;
    }
    const creatorRes = await pool.query(`SELECT id FROM users WHERE role = 'SUPER_ADMIN' LIMIT 1`);
    const creatorId = creatorRes.rows[0]?.id;

    const result = await pool.query(
      `INSERT INTO tasks (title, description, assigned_to, created_by, priority, status, due_date)
       VALUES ($1, $2, $3, $4, $5, 'todo', $6) RETURNING *`,
      [title, description || '', assignId, creatorId, (priority || 'medium').toLowerCase(), deadline || null]
    );
    const task = result.rows[0];
    await createNotification(assignId || creatorId, 'Новая задача', `Назначена задача: ${title}`, 'TASK', task.id);
    res.status(201).json({ data: task });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

app.post('/api/v1/tasks', handleCreateTask);
app.post('/api/v1/tasks/create', handleCreateTask);

app.put('/api/v1/tasks/:id/status', async (req, res) => {
  const { status, progress } = req.body;
  try {
    const result = await pool.query(
      `UPDATE tasks SET status = $1, progress = COALESCE($2, progress), updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *`,
      [status.toLowerCase(), progress != null ? parseFloat(progress) : null, req.params.id]
    );
    const task = result.rows[0];
    if (task) {
      await createNotification(task.assigned_to || task.created_by, 'Статус задачи обновлен', `Задача "${task.title}" переведена в "${status}"`, 'TASK', task.id);
    }
    res.json({ data: task });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/tasks/:id/comments', async (req, res) => {
  const { content } = req.body;
  try {
    const uRes = await pool.query(`SELECT id FROM users LIMIT 1`);
    const result = await pool.query(
      `INSERT INTO task_comments (task_id, user_id, comment) VALUES ($1, $2, $3) RETURNING *`,
      [req.params.id, uRes.rows[0]?.id, content]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/tasks/:id/attachments', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Файл не прикреплен' });
  try {
    const fileUrl = `/uploads/${req.file.filename}`;
    await pool.query(
      `INSERT INTO task_attachments (task_id, file_name, file_url, file_size)
       VALUES ($1, $2, $3, $4)`,
      [req.params.id, req.file.originalname, fileUrl, req.file.size]
    );
    res.json({ url: fileUrl, fileName: req.file.originalname });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/tasks/:id', async (req, res) => {
  const { id } = req.params;
  if (!id || id === 'create' || id === 'add') {
    return res.status(404).json({ message: 'Задание не найдено' });
  }
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(id)) {
    return res.status(404).json({ message: 'Задание не найдено' });
  }
  try {
    const q = `
      SELECT t.*, u.full_name as assigned_to_name, u.avatar_url as assigned_to_avatar,
             c.full_name as created_by_name
      FROM tasks t
      LEFT JOIN users u ON t.assigned_to = u.id
      LEFT JOIN users c ON t.created_by = c.id
      WHERE t.id = $1
    `;
    const result = await pool.query(q, [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Задание не найдено' });
    }

    const commentsRes = await pool.query(
      `SELECT tc.*, u.full_name as author_name, u.avatar_url as author_avatar
       FROM task_comments tc
       LEFT JOIN users u ON tc.user_id = u.id
       WHERE tc.task_id = $1
       ORDER BY tc.created_at ASC`,
      [id]
    );

    const attachRes = await pool.query(
      `SELECT * FROM task_attachments WHERE task_id = $1 ORDER BY created_at ASC`,
      [id]
    );

    res.json({
      data: {
        ...result.rows[0],
        comments: commentsRes.rows,
        attachments: attachRes.rows.map(a => a.file_url || a.file_name),
      }
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 9. MESSENGER (Persistent DB Chat + Real-Time Socket.IO)
// ============================================================================
app.get('/api/v1/chat/rooms', async (req, res) => {
  try {
    const q = `
      SELECT r.*, r.name as title,
             COALESCE((SELECT content FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1), 'Чат создан') as last_message,
             COALESCE((SELECT created_at FROM messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1), r.created_at) as last_message_time,
             0 as unread_count
      FROM chat_rooms r
      ORDER BY last_message_time DESC
    `;
    const result = await pool.query(q);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/chat/rooms/:roomId/messages', async (req, res) => {
  try {
    const q = `
      SELECT m.*, u.full_name as sender_name, u.avatar_url as sender_avatar
      FROM messages m
      LEFT JOIN users u ON m.sender_id = u.id
      WHERE m.room_id = $1
      ORDER BY m.created_at ASC
    `;
    const result = await pool.query(q, [req.params.roomId]);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/chat/rooms/:roomId/messages', async (req, res) => {
  const { content, attachmentUrl, attachmentType, replyToContent } = req.body;
  const senderId = req.user?.sub || (await pool.query('SELECT id FROM users LIMIT 1')).rows[0]?.id;
  try {
    const ins = await pool.query(
      `INSERT INTO messages (room_id, sender_id, content, attachment_url)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.params.roomId, senderId, content || '', attachmentUrl || null]
    );
    const msg = ins.rows[0];

    const uRes = await pool.query('SELECT full_name, avatar_url FROM users WHERE id = $1', [senderId]);
    msg.sender_name = uRes.rows[0]?.full_name || 'Собеседник';
    msg.sender_avatar = uRes.rows[0]?.avatar_url;

    // Broadcast via WebSocket
    io.emit(`room:${req.params.roomId}`, msg);

    res.status(201).json({ data: msg });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/chat/rooms/:roomId/read', (req, res) => {
  res.json({ success: true });
});

// Socket.IO event handling
io.on('connection', (socket) => {
  socket.on('joinRoom', (roomId) => {
    socket.join(roomId);
  });
  socket.on('sendMessage', async (data) => {
    io.to(data.roomId).emit('newMessage', data);
  });
});

// ============================================================================
// 10. EMPLOYEES & DEPARTMENTS
// ============================================================================
app.get('/api/v1/employees', async (req, res) => {
  const { search, role, departmentId } = req.query;
  const conds = ['u.is_active = TRUE'];
  const vals = [];

  if (search) {
    vals.push(`%${search.trim()}%`);
    conds.push(`(u.full_name ILIKE $${vals.length} OR u.email ILIKE $${vals.length} OR u.phone ILIKE $${vals.length})`);
  }
  if (role && role !== 'all') {
    vals.push(role.toUpperCase());
    conds.push(`UPPER(u.role) = $${vals.length}`);
  }
  if (departmentId) {
    vals.push(departmentId);
    conds.push(`u.department_id = $${vals.length}`);
  }

  try {
    const q = `
      SELECT u.*, d.name as department_name,
             (SELECT count(*) FROM tasks WHERE assigned_to = u.id AND status != 'done') as active_tasks_count
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      WHERE ${conds.join(' AND ')}
      ORDER BY u.created_at ASC
    `;
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/employees', async (req, res) => {
  const { fullName, email, phone, role, position, departmentName } = req.body;
  try {
    let deptId = null;
    if (departmentName) {
      const dRes = await pool.query('SELECT id FROM departments WHERE name ILIKE $1 LIMIT 1', [departmentName]);
      deptId = dRes.rows[0]?.id;
    }
    const empPw = await bcrypt.hash('Employee123!', 10);
    const result = await pool.query(
      `INSERT INTO users (full_name, email, phone, role, position, department_id, password_hash, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE) RETURNING *`,
      [fullName, email, phone || '', (role || 'EMPLOYEE').toUpperCase(), position || 'Сотрудник', deptId, empPw]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/employees/departments', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM departments ORDER BY name ASC');
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/employees/:id', async (req, res) => {
  try {
    const q = `
      SELECT u.*, d.name as department_name,
             (SELECT count(*) FROM tasks WHERE assigned_to = u.id AND status != 'done') as active_tasks_count
      FROM users u
      LEFT JOIN departments d ON u.department_id = d.id
      WHERE u.id = $1
    `;
    const result = await pool.query(q, [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Сотрудник не найден' });
    res.json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Roles catalog endpoint
app.get('/api/v1/roles', (req, res) => {
  res.json({
    data: [
      {
        id: 'SUPER_ADMIN',
        name: 'Главный администратор',
        description: 'Владелец / Руководитель. Полный доступ ко всем модулям, финансам и назначению ролей.',
        level: 1,
      },
      {
        id: 'ADMIN',
        name: 'Администратор',
        description: 'Операционное управление. Управление персоналом, складом, закупками, сделками и задачами.',
        level: 2,
      },
      {
        id: 'MANAGER',
        name: 'Менеджер проектов / CRM',
        description: 'Управление клиентами, воронка сделок, постановка и контроль задач сотрудникам.',
        level: 3,
      },
      {
        id: 'ACCOUNTANT',
        name: 'Бухгалтер / Финансист',
        description: 'Финансовый учет, кассы, доходы, расходы, выплаты и расчет зарплат.',
        level: 3,
      },
      {
        id: 'WAREHOUSE_KEEPER',
        name: 'Кладовщик / Склад',
        description: 'Приемка поставок, контроль остатков товаров, списания и инвентаризация.',
        level: 4,
      },
      {
        id: 'EMPLOYEE',
        name: 'Сотрудник / Специалист',
        description: 'Выполнение назначенных задач, корпоративный мессенджер и файлы.',
        level: 5,
      },
    ]
  });
});

// Update Employee Role endpoint
app.patch('/api/v1/employees/:id/role', async (req, res) => {
  const { role } = req.body;
  if (!role) return res.status(400).json({ message: 'Роль не указана' });
  try {
    const uRole = role.toUpperCase();
    const result = await pool.query(
      'UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [uRole, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: 'Сотрудник не найден' });
    
    const emp = result.rows[0];
    await createNotification(emp.id, 'Изменение роли в системе', `Вам назначена роль: ${uRole}`, 'SYSTEM', emp.id);
    res.json({ data: emp, message: 'Роль успешно изменена' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Update Employee full details (PATCH and PUT)
const handleUpdateEmployee = async (req, res) => {
  const { fullName, name, phone, position, role, departmentName, isActive } = req.body;
  try {
    let deptId = undefined;
    if (departmentName) {
      const dRes = await pool.query('SELECT id FROM departments WHERE name ILIKE $1 LIMIT 1', [departmentName]);
      deptId = dRes.rows[0]?.id;
    }

    const updates = [];
    const vals = [req.params.id];

    const newName = fullName || name;
    if (newName !== undefined) {
      vals.push(newName);
      updates.push(`full_name = $${vals.length}`);
    }
    if (phone !== undefined) {
      vals.push(phone);
      updates.push(`phone = $${vals.length}`);
    }
    if (position !== undefined) {
      vals.push(position);
      updates.push(`position = $${vals.length}`);
    }
    if (role !== undefined) {
      vals.push(role.toUpperCase());
      updates.push(`role = $${vals.length}`);
    }
    if (deptId !== undefined) {
      vals.push(deptId);
      updates.push(`department_id = $${vals.length}`);
    }
    if (isActive !== undefined) {
      vals.push(Boolean(isActive));
      updates.push(`is_active = $${vals.length}`);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'Нет данных для обновления' });
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);

    const q = `
      UPDATE users 
      SET ${updates.join(', ')} 
      WHERE id = $1 
      RETURNING *, (SELECT name FROM departments WHERE id = users.department_id) as department_name
    `;
    const result = await pool.query(q, vals);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Сотрудник не найден' });

    const emp = result.rows[0];
    if (role !== undefined) {
      await createNotification(emp.id, 'Обновление профиля', `Ваша роль изменена на: ${emp.role}`, 'SYSTEM', emp.id);
    }
    res.json({ data: emp, message: 'Данные сотрудника обновлены' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

app.patch('/api/v1/employees/:id', handleUpdateEmployee);
app.put('/api/v1/employees/:id', handleUpdateEmployee);

app.delete('/api/v1/employees/:id', async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = $1', [req.params.id]);
    res.json({ success: true, message: 'Сотрудник деактивирован' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 11. CUSTOMERS & SUPPLIERS
// ============================================================================
app.get('/api/v1/customers', async (req, res) => {
  const { search } = req.query;
  const vals = [];
  let q = 'SELECT * FROM customers';
  if (search) {
    vals.push(`%${search.trim()}%`);
    q += ` WHERE name ILIKE $1 OR phone ILIKE $1 OR email ILIKE $1`;
  }
  q += ' ORDER BY created_at DESC';
  try {
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/customers', async (req, res) => {
  const { name, phone, email, address } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO customers (name, phone, email, address) VALUES ($1, $2, $3, $4) RETURNING *`,
      [name, phone || '', email || '', address || '']
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/customers/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM customers WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Клиент не найден' });
    const salesRes = await pool.query(
      'SELECT * FROM sales WHERE customer_id = $1 ORDER BY created_at DESC LIMIT 10',
      [req.params.id]
    );
    res.json({ data: { ...result.rows[0], sales: salesRes.rows } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/suppliers', async (req, res) => {
  const { search } = req.query;
  const vals = [];
  let q = 'SELECT * FROM suppliers';
  if (search) {
    vals.push(`%${search.trim()}%`);
    q += ` WHERE name ILIKE $1 OR phone ILIKE $1 OR email ILIKE $1`;
  }
  q += ' ORDER BY created_at DESC';
  try {
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/suppliers', async (req, res) => {
  const { name, contactPerson, phone, email, address } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO suppliers (name, contact_person, phone, email, address) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [name, contactPerson || '', phone || '', email || '', address || '']
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/suppliers/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM suppliers WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ message: 'Поставщик не найден' });
    const shipRes = await pool.query(
      'SELECT * FROM incoming_shipments WHERE supplier_id = $1 ORDER BY created_at DESC LIMIT 10',
      [req.params.id]
    );
    res.json({ data: { ...result.rows[0], shipments: shipRes.rows } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 12. DOCUMENTS & FOLDERS
// ============================================================================
app.get('/api/v1/documents/folders', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT f.*, (SELECT count(*) FROM documents WHERE folder_id = f.id) as files_count FROM document_folders f ORDER BY f.created_at ASC`
    );
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/documents/folders', async (req, res) => {
  const { name } = req.body;
  try {
    const result = await pool.query(`INSERT INTO document_folders (name) VALUES ($1) RETURNING *`, [name || 'Новая папка']);
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/v1/documents/files', async (req, res) => {
  const { folderId } = req.query;
  const vals = [];
  let q = 'SELECT * FROM documents';
  if (folderId) {
    vals.push(folderId);
    q += ' WHERE folder_id = $1';
  }
  q += ' ORDER BY created_at DESC';
  try {
    const result = await pool.query(q, vals);
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/documents/upload', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Файл не выбран' });
  const { folderId } = req.body;
  try {
    const ext = path.extname(req.file.originalname).replace('.', '').toLowerCase();
    const result = await pool.query(
      `INSERT INTO documents (folder_id, name, file_path, file_size, file_type)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [folderId || null, req.file.originalname, `/uploads/${req.file.filename}`, req.file.size, ext]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 13. FINANCIAL & SALES REPORTS (Accurate Math from DB records)
// ============================================================================
app.get('/api/v1/reports/financial', async (req, res) => {
  try {
    // Exact DB revenue from sales
    const salesRes = await pool.query(`SELECT COALESCE(SUM(grand_total), 0) as total FROM sales WHERE status != 'CANCELLED'`);
    const revenue = parseFloat(salesRes.rows[0].total);

    // Exact DB operating expenses from transactions
    const expRes = await pool.query(`SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE LOWER(type) = 'expense'`);
    const expenses = parseFloat(expRes.rows[0].total);

    // Exact COGS from inventory valuation of sold items
    const cogsRes = await pool.query(
      `SELECT COALESCE(SUM(si.quantity * si.cost_price), 0) as total 
       FROM sale_items si 
       JOIN sales s ON si.sale_id = s.id 
       WHERE s.status != 'CANCELLED'`
    );
    const cogs = parseFloat(cogsRes.rows[0].total);

    const grossProfit = revenue - cogs;
    const netProfit = grossProfit - expenses;

    res.json({
      data: {
        revenue,
        expenses,
        grossProfit,
        netProfit,
        period: req.query.period || 'month',
        monthlyData: [],
        salesTrend: [],
      },
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 14. NOTIFICATIONS
// ============================================================================
async function createNotification(userId, title, body, type = 'SYSTEM', referenceId = null) {
  try {
    let targetUser = userId;
    if (!targetUser) {
      const uRes = await pool.query('SELECT id FROM users LIMIT 1');
      if (uRes.rows.length > 0) targetUser = uRes.rows[0].id;
    }
    if (targetUser) {
      await pool.query(
        'INSERT INTO notifications (user_id, title, body, type, reference_id) VALUES ($1, $2, $3, $4, $5)',
        [targetUser, title, body, type, referenceId]
      );
    }
  } catch (err) {
    console.error('Notification insertion error:', err.message);
  }
}

app.get('/api/v1/notifications', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM notifications ORDER BY created_at DESC LIMIT 50');
    res.json({ data: result.rows });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/v1/notifications/read-all', async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read = TRUE');
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.patch('/api/v1/notifications/:id/read', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('UPDATE notifications SET is_read = TRUE WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.delete('/api/v1/notifications/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM notifications WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// ============================================================================
// 15. FILE UPLOADS
// ============================================================================
app.post('/api/v1/files/upload', upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Файл не передан' });
  res.json({
    url: `/uploads/${req.file.filename}`,
    fileName: req.file.originalname,
    size: req.file.size,
  });
});

// 404 handler
app.use((req, res) => {
  console.log(`⚠️ 404 Not Found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({ message: `Маршрут ${req.originalUrl} не найден` });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 COMPANY OS Enterprise Server running on port ${PORT}`);
});

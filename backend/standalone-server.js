const express = require('express');
const cors = require('cors');
const http = require('http');
const crypto = require('crypto');
const { Server } = require('socket.io');
const { Pool, types } = require('pg');

// DATE columns are calendar days; keep them as 'YYYY-MM-DD' instead of letting
// node-postgres turn them into a server-local midnight timestamp.
types.setTypeParser(1082, (value) => value);
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const apns = require('./apns');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
const PORT = process.env.PORT || 3000;

const DEV_JWT_SECRET = 'company_os_jwt_secret_key_2026_super_secure';
const JWT_SECRET = process.env.JWT_SECRET || DEV_JWT_SECRET;
if (JWT_SECRET === DEV_JWT_SECRET) {
  console.warn('⚠️  JWT_SECRET is not set. The built-in secret is public; set JWT_SECRET before serving real users.');
}
const ACCESS_TTL = process.env.JWT_EXPIRES_IN || '7d';
const REFRESH_TTL = process.env.JWT_REFRESH_EXPIRES_IN || '30d';
const PUBLIC_URL = (process.env.PUBLIC_URL || '').replace(/\/$/, '');

// ============================================================================
// INFRASTRUCTURE
// ============================================================================
const uploadDir = path.join(__dirname, 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase().replace(/[^.a-z0-9]/g, '').slice(0, 10);
      cb(null, `${Date.now()}-${crypto.randomBytes(12).toString('hex')}${ext}`);
    },
  }),
  limits: { fileSize: 25 * 1024 * 1024 },
});

const pool = new Pool({
  host: process.env.DB_HOST || '172.17.0.5',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'company_os',
  user: process.env.DB_USER || 'company_os_user',
  password: process.env.DB_PASSWORD || 'company_os_password_2026',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pool.query('SELECT NOW()', (err, res) => {
  if (err) console.error('❌ Database connection error:', err.message);
  else console.log('✅ PostgreSQL connected successfully at:', res.rows[0].now);
});

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);
const uuidOrNull = (v) => (isUuid(v) ? v : null);
const str = (v) => (v == null ? '' : String(v).trim());
const strOrNull = (v) => (str(v) === '' ? null : str(v));

function num(v, fallback = 0) {
  if (typeof v === 'number') return Number.isFinite(v) ? v : fallback;
  if (v == null) return fallback;
  const n = parseFloat(String(v).replace(/\s/g, '').replace(',', '.'));
  return Number.isFinite(n) ? n : fallback;
}

// "1 200 000" with thin grouping spaces, as amounts are written in the app.
function money(v) {
  const n = Math.round(num(v) * 100) / 100;
  return n.toLocaleString('ru-RU', { maximumFractionDigits: 2 }).replace(/\u00a0/g, ' ');
}

function requirePositive(v, label) {
  const n = num(v, NaN);
  if (!Number.isFinite(n) || n <= 0) throw new HttpError(400, `${label} должна быть больше 0`);
  return Math.round(n * 100) / 100;
}

function dateOrToday(v) {
  if (!v) return new Date().toISOString().slice(0, 10);
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return new Date().toISOString().slice(0, 10);
  // The app sends local midnight as an ISO string; keep the calendar day the user picked.
  const s = String(v);
  return /^\d{4}-\d{2}-\d{2}/.test(s) ? s.slice(0, 10) : d.toISOString().slice(0, 10);
}

const NUMERIC_KEY = /(^|_)(amount|balance|price|cost|total|subtotal|quantity|discount|tax|salary|costs|paid|debt|value|level|count|progress|size)($|_)/;

// Rows go out with their snake_case columns plus camelCase aliases, and DECIMAL
// columns as numbers, because the app models read either spelling.
function out(row) {
  if (row == null || typeof row !== 'object') return row;
  if (Array.isArray(row)) return row.map(out);
  if (row instanceof Date) return row;
  const res = {};
  for (const [k, raw] of Object.entries(row)) {
    if (k === 'password_hash' || k === 'token_version' || k === 'fcm_token') continue;
    let v = raw;
    if (typeof v === 'string' && NUMERIC_KEY.test(k) && /^-?\d+(\.\d+)?$/.test(v)) v = parseFloat(v);
    else if (v && typeof v === 'object' && !(v instanceof Date)) v = out(v);
    res[k] = v;
    const camel = k.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
    if (camel !== k && !(camel in row)) res[camel] = v;
  }
  return res;
}

const h = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

async function tx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

function fileUrl(relative) {
  if (!relative) return relative;
  return PUBLIC_URL && relative.startsWith('/') ? `${PUBLIC_URL}${relative}` : relative;
}

// multer decodes multipart file names as latin1; browsers and Dio send UTF-8.
function originalName(file) {
  const raw = file.originalname || 'file';
  const decoded = Buffer.from(raw, 'latin1').toString('utf8');
  return decoded.includes('\uFFFD') ? raw : decoded;
}

function removeUploadedFile(url) {
  if (!url) return;
  const name = path.basename(String(url).split('?')[0]);
  const full = path.join(uploadDir, name);
  if (full.startsWith(uploadDir + path.sep)) fs.unlink(full, () => {});
}

app.set('trust proxy', true);
app.use(cors({ origin: '*', credentials: true }));
app.use(express.json({ limit: '2mb' }));
app.use('/uploads', express.static(uploadDir, { fallthrough: false, index: false }));

const webDir = path.join(__dirname, 'web');
if (fs.existsSync(webDir)) app.use(express.static(webDir));

app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.ip} -> ${req.method} ${req.originalUrl.split('?')[0]}`);
  next();
});

// ============================================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================================
const ADMIN_ROLES = new Set(['OWNER', 'SUPER_ADMIN', 'ADMIN']);
const ROLE_IDS = ['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'ACCOUNTANT', 'WAREHOUSE_KEEPER', 'EMPLOYEE'];

function signTokens(user) {
  const base = { sub: user.id, email: user.email, tv: user.token_version || 0 };
  return {
    accessToken: jwt.sign({ ...base, typ: 'access' }, JWT_SECRET, { expiresIn: ACCESS_TTL }),
    refreshToken: jwt.sign({ ...base, typ: 'refresh' }, JWT_SECRET, { expiresIn: REFRESH_TTL }),
  };
}

async function resolveMembership(userId, preferredCompanyId) {
  const res = await pool.query(
    `SELECT uc.company_id, uc.role
     FROM user_companies uc JOIN companies c ON c.id = uc.company_id AND c.is_active
     WHERE uc.user_id = $1
     ORDER BY (uc.company_id = $2) DESC, uc.is_default DESC, uc.created_at ASC
     LIMIT 1`,
    [userId, preferredCompanyId]
  );
  return res.rows[0] || null;
}

async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new HttpError(401, 'Требуется авторизация');

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (e) {
      throw new HttpError(401, 'Сессия истекла. Войдите снова');
    }
    if (decoded.typ === 'refresh') throw new HttpError(401, 'Недействительный токен');

    const userRes = await pool.query(
      `SELECT id, email, full_name, role, is_active, token_version, current_company_id FROM users WHERE id = $1`,
      [decoded.sub]
    );
    const user = userRes.rows[0];
    if (!user || !user.is_active) throw new HttpError(401, 'Учётная запись недоступна');
    if (decoded.tv != null && decoded.tv !== user.token_version) throw new HttpError(401, 'Сессия истекла. Войдите снова');

    const membership = await resolveMembership(user.id, user.current_company_id);
    req.user = { id: user.id, sub: user.id, email: user.email, fullName: user.full_name };
    req.companyId = membership ? membership.company_id : null;
    req.companyRole = membership ? membership.role : null;
    if (membership && membership.company_id !== user.current_company_id) {
      await pool.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [membership.company_id, user.id]);
    }
    next();
  } catch (err) {
    next(err);
  }
}

function requireCompany(req, res, next) {
  if (!req.companyId) return next(new HttpError(409, 'У вас нет организации. Создайте организацию в разделе «Мои организации»'));
  next();
}

function requireAdmin(req, res, next) {
  if (!ADMIN_ROLES.has(req.companyRole)) return next(new HttpError(403, 'Недостаточно прав для этого действия'));
  next();
}

const appRole = (companyRole) => (companyRole === 'OWNER' ? 'SUPER_ADMIN' : companyRole || 'EMPLOYEE');

// Attempts per (ip, email) in a sliding window; keeps password guessing slow.
const loginAttempts = new Map();
function checkLoginRate(key) {
  const now = Date.now();
  const windowMs = 15 * 60 * 1000;
  const list = (loginAttempts.get(key) || []).filter((t) => now - t < windowMs);
  if (list.length >= 10) throw new HttpError(429, 'Слишком много попыток входа. Повторите через 15 минут');
  list.push(now);
  loginAttempts.set(key, list);
}
setInterval(() => {
  const now = Date.now();
  for (const [k, list] of loginAttempts) {
    if (list.every((t) => now - t > 15 * 60 * 1000)) loginAttempts.delete(k);
  }
}, 5 * 60 * 1000).unref();

// ============================================================================
// PUBLIC ROUTES
// ============================================================================
const api = express.Router();
app.use('/api/v1', api);

api.get('/health', h(async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', server: 'COMPANY OS Server', database: 'connected', timestamp: new Date().toISOString() });
  } catch (e) {
    res.status(503).json({ status: 'degraded', database: 'error', timestamp: new Date().toISOString() });
  }
}));

const updatesDir = path.join(__dirname, 'updates');
try { fs.mkdirSync(updatesDir, { recursive: true }); } catch (e) { /* read-only deploys */ }

const currentAppVersion = {
  versionCode: 5,
  versionName: '1.1.0',
  minSupportedVersion: 1,
  fileSize: 0,
  title: 'Обновление Company OS v1.1.0',
  changelog: [
    'Раздельные данные для каждой организации',
    'Тёмная тема',
    'Исправлено сохранение доходов и расходов',
    'Просмотр и удаление прикреплённых документов',
  ],
  forceUpdate: false,
  releaseDate: '2026-11-19T00:00:00Z',
};

api.get('/app/version', (req, res) => {
  const apkPath = path.join(updatesDir, 'CompanyOS-latest.apk');
  const hasApk = fs.existsSync(apkPath);
  const base = PUBLIC_URL || `${req.protocol}://${req.get('host')}`;
  res.json({
    ...currentAppVersion,
    fileSize: hasApk ? fs.statSync(apkPath).size : 0,
    downloadUrl: hasApk ? `${base}/api/v1/app/download` : null,
  });
});

api.get('/app/download', (req, res) => {
  const apkPath = path.join(updatesDir, 'CompanyOS-latest.apk');
  if (!fs.existsSync(apkPath)) return res.status(404).json({ message: 'Файл обновления не найден на сервере' });
  res.setHeader('Content-Type', 'application/vnd.android.package-archive');
  res.download(apkPath, 'CompanyOS-latest.apk');
});

async function userProfile(userId) {
  const res = await pool.query(
    `SELECT u.*, d.name AS department_name FROM users u LEFT JOIN departments d ON u.department_id = d.id WHERE u.id = $1`,
    [userId]
  );
  const u = res.rows[0];
  if (!u) return null;
  const membership = await resolveMembership(u.id, u.current_company_id);
  return {
    id: u.id,
    email: u.email,
    fullName: u.full_name,
    role: membership ? appRole(membership.role) : u.role,
    departmentId: u.department_id,
    departmentName: u.department_name || null,
    phone: u.phone,
    avatarUrl: u.avatar_url,
    position: u.position,
    isActive: u.is_active,
    createdAt: u.created_at,
    companyId: membership ? membership.company_id : null,
    pushEnabled: u.push_enabled,
    emailEnabled: u.email_enabled,
  };
}

async function createCompanyDefaults(client, companyId, currency) {
  await client.query(
    `INSERT INTO accounts (name, type, balance, currency, company_id)
     VALUES ('Касса (Наличные)', 'CASH', 0, $1, $2), ('Расчётный счёт (Банк)', 'BANK', 0, $1, $2)`,
    [currency, companyId]
  );
  await client.query(`INSERT INTO warehouses (name, is_default, company_id) VALUES ('Основной склад', TRUE, $1)`, [companyId]);
  await client.query(`INSERT INTO departments (name, company_id) VALUES ('Руководство', $1)`, [companyId]);
}

async function createCompany(client, userId, fields) {
  const currency = str(fields.currency) || 'UZS';
  const compRes = await client.query(
    `INSERT INTO companies (name, tax_id, currency, description, address, phone, email, logo_url, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
    [str(fields.name), strOrNull(fields.taxId), currency, str(fields.description), str(fields.address),
      str(fields.phone), str(fields.email), strOrNull(fields.logoUrl), userId]
  );
  const company = compRes.rows[0];
  await client.query(
    `INSERT INTO user_companies (user_id, company_id, role, is_default)
     VALUES ($1, $2, 'OWNER', NOT EXISTS (SELECT 1 FROM user_companies WHERE user_id = $1))`,
    [userId, company.id]
  );
  await client.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [company.id, userId]);
  await createCompanyDefaults(client, company.id, currency);
  return company;
}

api.post('/auth/login', h(async (req, res) => {
  const email = str(req.body && req.body.email).toLowerCase();
  const password = req.body && typeof req.body.password === 'string' ? req.body.password : '';
  if (!email || !password) throw new HttpError(400, 'Введите электронную почту и пароль');
  checkLoginRate(`${req.ip}|${email}`);

  const result = await pool.query(`SELECT * FROM users WHERE LOWER(email) = $1`, [email]);
  const user = result.rows[0];
  const ok = user && user.is_active && user.password_hash && await bcrypt.compare(password, user.password_hash);
  if (!ok) throw new HttpError(401, 'Неверный адрес электронной почты или пароль');

  loginAttempts.delete(`${req.ip}|${email}`);
  res.json({ ...signTokens(user), user: await userProfile(user.id) });
}));

api.post('/auth/register', h(async (req, res) => {
  const body = req.body || {};
  const email = str(body.email).toLowerCase();
  const fullName = str(body.fullName);
  const password = typeof body.password === 'string' ? body.password : '';
  if (!email || !password || !fullName) throw new HttpError(400, 'Заполните все обязательные поля: Email, Пароль, ФИО');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'Укажите корректный адрес электронной почты');
  if (password.length < 6) throw new HttpError(400, 'Пароль должен содержать не менее 6 символов');
  checkLoginRate(`${req.ip}|register`);

  const user = await tx(async (client) => {
    const existing = await client.query('SELECT id FROM users WHERE LOWER(email) = $1', [email]);
    if (existing.rows.length > 0) throw new HttpError(400, 'Пользователь с таким Email уже зарегистрирован');

    const insertRes = await client.query(
      `INSERT INTO users (email, password_hash, full_name, phone, role, position, is_active)
       VALUES ($1, $2, $3, $4, 'SUPER_ADMIN', $5, TRUE) RETURNING *`,
      [email, await bcrypt.hash(password, 10), fullName, strOrNull(body.phone), str(body.position) || 'Руководитель']
    );
    const created = insertRes.rows[0];
    // Every self-registered account owns its own organization and starts with no one else's data.
    const company = await createCompany(client, created.id, { name: str(body.companyName) || `Компания ${fullName}` });
    const dept = await client.query(`SELECT id FROM departments WHERE company_id = $1 LIMIT 1`, [company.id]);
    await client.query(`UPDATE users SET department_id = $1 WHERE id = $2`, [dept.rows[0] ? dept.rows[0].id : null, created.id]);
    return created;
  });

  res.status(201).json({ ...signTokens(user), user: await userProfile(user.id) });
}));

api.post('/auth/refresh', h(async (req, res) => {
  const refreshToken = req.body && req.body.refreshToken;
  if (!refreshToken) throw new HttpError(400, 'Токен обязателен');
  let decoded;
  try {
    decoded = jwt.verify(refreshToken, JWT_SECRET);
  } catch (e) {
    throw new HttpError(401, 'Токен истек или недействителен');
  }
  if (decoded.typ === 'access') throw new HttpError(401, 'Токен истек или недействителен');
  const userRes = await pool.query(`SELECT * FROM users WHERE id = $1`, [decoded.sub]);
  const user = userRes.rows[0];
  if (!user || !user.is_active || (decoded.tv != null && decoded.tv !== user.token_version)) {
    throw new HttpError(401, 'Токен истек или недействителен');
  }
  res.json(signTokens(user));
}));

// ============================================================================
// EVERYTHING BELOW REQUIRES A VALID SESSION
// ============================================================================
api.use(authenticate);

api.get('/auth/me', h(async (req, res) => {
  res.json(await userProfile(req.user.id));
}));

api.post('/auth/logout', h(async (req, res) => {
  const token = str(req.body && req.body.deviceToken);
  if (token) await pool.query('DELETE FROM device_tokens WHERE token = $1 AND user_id = $2', [token, req.user.id]);
  res.json({ success: true });
}));

// Phones register here to receive push notifications for the signed-in user.
api.post('/devices', h(async (req, res) => {
  const b = req.body || {};
  const token = str(b.token);
  const platform = str(b.platform).toLowerCase();
  if (!/^[0-9a-f]{32,200}$/i.test(token) || !['ios', 'android'].includes(platform)) throw new HttpError(400, 'Некорректные данные устройства');
  const environment = str(b.environment) === 'sandbox' ? 'sandbox' : 'production';
  // A phone belongs to whoever signed in on it last.
  await pool.query(
    `INSERT INTO device_tokens (token, user_id, platform, environment) VALUES ($1, $2, $3, $4)
     ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform,
       environment = EXCLUDED.environment, updated_at = CURRENT_TIMESTAMP`,
    [token, req.user.id, platform, environment]
  );
  res.json({ success: true, pushAvailable: platform !== 'ios' || apns.enabled });
}));

api.delete('/devices', h(async (req, res) => {
  const token = str((req.body && req.body.token) || req.query.token);
  if (token) await pool.query('DELETE FROM device_tokens WHERE token = $1 AND user_id = $2', [token, req.user.id]);
  res.json({ success: true });
}));

api.patch('/auth/profile', h(async (req, res) => {
  const b = req.body || {};
  const sets = [];
  const vals = [req.user.id];
  const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
  if (b.fullName !== undefined) {
    if (!str(b.fullName)) throw new HttpError(400, 'Укажите имя');
    set('full_name', str(b.fullName));
  }
  if (b.phone !== undefined) set('phone', strOrNull(b.phone));
  if (b.position !== undefined) set('position', strOrNull(b.position));
  if (b.avatarUrl !== undefined) set('avatar_url', strOrNull(b.avatarUrl));
  if (b.pushEnabled !== undefined) set('push_enabled', Boolean(b.pushEnabled));
  if (b.emailEnabled !== undefined) set('email_enabled', Boolean(b.emailEnabled));
  if (sets.length === 0) throw new HttpError(400, 'Нет данных для обновления');
  await pool.query(`UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, vals);
  res.json(await userProfile(req.user.id));
}));

api.post('/auth/change-password', h(async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (typeof newPassword !== 'string' || newPassword.length < 6) throw new HttpError(400, 'Новый пароль должен содержать не менее 6 символов');
  const userRes = await pool.query(`SELECT * FROM users WHERE id = $1`, [req.user.id]);
  const user = userRes.rows[0];
  if (!(await bcrypt.compare(String(currentPassword || ''), user.password_hash || ''))) {
    throw new HttpError(400, 'Текущий пароль указан неверно');
  }
  const updated = await pool.query(
    `UPDATE users SET password_hash = $1, token_version = token_version + 1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *`,
    [await bcrypt.hash(newPassword, 10), req.user.id]
  );
  res.json({ success: true, message: 'Пароль изменён', ...signTokens(updated.rows[0]) });
}));

const COMPANY_TABLES = [
  'payments', 'transactions', 'accounts', 'stock_movements', 'sales', 'incoming_shipments', 'deals', 'tasks',
  'documents', 'document_folders', 'chat_rooms', 'products', 'product_categories', 'warehouses',
  'customers', 'suppliers',
];

async function deleteCompanyData(client, companyId) {
  const files = await client.query(
    `SELECT file_path AS url FROM documents WHERE company_id = $1
     UNION ALL SELECT document_url FROM transactions WHERE company_id = $1 AND document_url IS NOT NULL
     UNION ALL SELECT ta.file_url FROM task_attachments ta JOIN tasks t ON t.id = ta.task_id WHERE t.company_id = $1`,
    [companyId]
  );
  await client.query(`DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE company_id = $1)`, [companyId]);
  await client.query(`DELETE FROM incoming_shipment_items WHERE shipment_id IN (SELECT id FROM incoming_shipments WHERE company_id = $1)`, [companyId]);
  for (const t of COMPANY_TABLES) await client.query(`DELETE FROM ${t} WHERE company_id = $1`, [companyId]);
  await client.query(`UPDATE users SET department_id = NULL WHERE department_id IN (SELECT id FROM departments WHERE company_id = $1)`, [companyId]);
  await client.query(`DELETE FROM departments WHERE company_id = $1`, [companyId]);
  await client.query(`UPDATE users SET current_company_id = NULL WHERE current_company_id = $1`, [companyId]);
  await client.query(`DELETE FROM companies WHERE id = $1`, [companyId]);
  return files.rows.map((r) => r.url);
}

api.delete('/auth/account', h(async (req, res) => {
  const password = String((req.body && req.body.password) || '');
  const userRes = await pool.query(`SELECT * FROM users WHERE id = $1`, [req.user.id]);
  const user = userRes.rows[0];
  if (!(await bcrypt.compare(password, user.password_hash || ''))) throw new HttpError(400, 'Пароль указан неверно');

  const filesToRemove = await tx(async (client) => {
    // Organizations where this user is the only owner go away with the account.
    const owned = await client.query(
      `SELECT uc.company_id FROM user_companies uc
       WHERE uc.user_id = $1 AND uc.role = 'OWNER'
         AND NOT EXISTS (SELECT 1 FROM user_companies o WHERE o.company_id = uc.company_id AND o.role = 'OWNER' AND o.user_id <> $1)`,
      [user.id]
    );
    let files = [];
    for (const row of owned.rows) files = files.concat(await deleteCompanyData(client, row.company_id));
    await client.query(`DELETE FROM users WHERE id = $1`, [user.id]);
    return files;
  });
  filesToRemove.forEach(removeUploadedFile);
  res.json({ success: true, message: 'Учётная запись удалена' });
}));

// ============================================================================
// COMPANIES & ORGANIZATIONS
// ============================================================================
api.get('/companies', h(async (req, res) => {
  const result = await pool.query(
    `SELECT c.*, uc.role AS user_role, (c.id = $2) AS is_current
     FROM companies c JOIN user_companies uc ON uc.company_id = c.id AND uc.user_id = $1
     WHERE c.is_active
     ORDER BY is_current DESC, c.created_at ASC`,
    [req.user.id, req.companyId]
  );
  res.json({ data: out(result.rows) });
}));

api.get('/companies/current', h(async (req, res) => {
  if (!req.companyId) return res.json({ data: null });
  const result = await pool.query(`SELECT *, TRUE AS is_current, $2::text AS user_role FROM companies WHERE id = $1`, [req.companyId, req.companyRole]);
  res.json({ data: out(result.rows[0] || null) });
}));

api.post('/companies', h(async (req, res) => {
  const body = req.body || {};
  if (!str(body.name)) throw new HttpError(400, 'Название компании обязательно');
  const company = await tx((client) => createCompany(client, req.user.id, body));
  await notify(req.user.id, 'Организация создана', `Компания "${company.name}" успешно зарегистрирована`, 'SYSTEM', company.id);
  res.status(201).json({ data: out({ ...company, is_current: true, user_role: 'OWNER' }) });
}));

api.post('/companies/switch', h(async (req, res) => {
  const companyId = req.body && req.body.companyId;
  if (!isUuid(companyId)) throw new HttpError(400, 'companyId обязателен');
  const result = await pool.query(
    `SELECT c.*, uc.role AS user_role FROM companies c
     JOIN user_companies uc ON uc.company_id = c.id AND uc.user_id = $1
     WHERE c.id = $2 AND c.is_active`,
    [req.user.id, companyId]
  );
  if (result.rows.length === 0) throw new HttpError(404, 'Компания не найдена');
  await pool.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [companyId, req.user.id]);
  res.json({ success: true, message: `Переключено на компанию: ${result.rows[0].name}`, data: out({ ...result.rows[0], is_current: true }) });
}));

api.patch('/companies/:id', h(async (req, res) => {
  const member = await pool.query(`SELECT role FROM user_companies WHERE user_id = $1 AND company_id = $2`, [req.user.id, uuidOrNull(req.params.id)]);
  if (!member.rows[0]) throw new HttpError(404, 'Компания не найдена');
  if (!ADMIN_ROLES.has(member.rows[0].role)) throw new HttpError(403, 'Недостаточно прав для этого действия');
  const b = req.body || {};
  if (b.name !== undefined && !str(b.name)) throw new HttpError(400, 'Название компании обязательно');
  const result = await pool.query(
    `UPDATE companies SET
       name = COALESCE($2, name), tax_id = COALESCE($3, tax_id), currency = COALESCE($4, currency),
       description = COALESCE($5, description), address = COALESCE($6, address), phone = COALESCE($7, phone),
       email = COALESCE($8, email), logo_url = COALESCE($9, logo_url), updated_at = CURRENT_TIMESTAMP
     WHERE id = $1 RETURNING *`,
    [req.params.id, strOrNull(b.name), strOrNull(b.taxId), strOrNull(b.currency), b.description === undefined ? null : str(b.description),
      b.address === undefined ? null : str(b.address), b.phone === undefined ? null : str(b.phone),
      b.email === undefined ? null : str(b.email), strOrNull(b.logoUrl)]
  );
  res.json({ data: out({ ...result.rows[0], is_current: result.rows[0].id === req.companyId, user_role: member.rows[0].role }) });
}));

api.delete('/companies/:id', h(async (req, res) => {
  const id = uuidOrNull(req.params.id);
  const member = await pool.query(`SELECT role FROM user_companies WHERE user_id = $1 AND company_id = $2`, [req.user.id, id]);
  if (!member.rows[0]) throw new HttpError(404, 'Компания не найдена');
  if (member.rows[0].role !== 'OWNER') throw new HttpError(403, 'Удалить организацию может только её владелец');
  const count = await pool.query(`SELECT count(*)::int AS n FROM user_companies WHERE user_id = $1`, [req.user.id]);
  if (count.rows[0].n <= 1) throw new HttpError(400, 'Нельзя удалить единственную организацию. Сначала создайте другую');

  const files = await tx((client) => deleteCompanyData(client, id));
  files.forEach(removeUploadedFile);
  const next = await resolveMembership(req.user.id, null);
  if (next) await pool.query(`UPDATE users SET current_company_id = $1 WHERE id = $2`, [next.company_id, req.user.id]);
  res.json({ success: true, message: 'Организация удалена', currentCompanyId: next ? next.company_id : null });
}));

// File upload does not depend on the active organization.
api.post('/files/upload', upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'Файл не передан' });
  res.json({ url: fileUrl(`/uploads/${req.file.filename}`), fileName: originalName(req.file), size: req.file.size });
});

api.delete('/files', h(async (req, res) => {
  const url = str(req.query.url || (req.body && req.body.url));
  if (!url) throw new HttpError(400, 'Не указан файл');
  const name = path.basename(url.split('?')[0]);
  // A file still referenced by a saved record is removed through that record, not here.
  const used = await pool.query(
    `SELECT 1 FROM transactions WHERE document_url LIKE $1
     UNION ALL SELECT 1 FROM documents WHERE file_path LIKE $1
     UNION ALL SELECT 1 FROM task_attachments WHERE file_url LIKE $1 LIMIT 1`,
    [`%/${name}`]
  );
  if (used.rows.length === 0) removeUploadedFile(url);
  res.json({ success: true });
}));

api.use(requireCompany);

// ============================================================================
// DASHBOARD & REPORTS
// ============================================================================
function periodRange(period) {
  const now = new Date();
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  if (period === 'week') start.setDate(start.getDate() - 6);
  else if (period === 'year') start.setMonth(0, 1);
  else if (period !== 'today') start.setDate(1);
  const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return { from: iso(start), to: iso(now) };
}

const normalizePeriod = (p) => (['today', 'week', 'month', 'year'].includes(p) ? p : 'month');

api.get('/dashboard/stats', h(async (req, res) => {
  const period = normalizePeriod(req.query.period);
  const { from, to } = periodRange(period);
  const cid = req.companyId;

  const [acc, flow, sales, inv, prod, deals, tasks, cust, supp] = await Promise.all([
    pool.query(`SELECT COALESCE(SUM(balance), 0) AS total FROM accounts WHERE company_id = $1 AND is_active`, [cid]),
    pool.query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE type = 'INCOME'), 0) AS income,
              COALESCE(SUM(amount) FILTER (WHERE type = 'EXPENSE'), 0) AS expenses
       FROM transactions WHERE company_id = $1 AND transaction_date BETWEEN $2 AND $3`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT COALESCE(SUM(grand_total), 0) AS total FROM sales
       WHERE company_id = $1 AND status <> 'CANCELLED' AND created_at::date BETWEEN $2 AND $3`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT COALESCE(SUM(i.quantity * i.average_cost), 0) AS total
       FROM inventory i JOIN products p ON p.id = i.product_id WHERE p.company_id = $1 AND p.is_active`,
      [cid]
    ),
    pool.query(`SELECT count(*)::int AS total FROM products WHERE company_id = $1 AND is_active`, [cid]),
    pool.query(`SELECT count(*)::int AS total FROM deals WHERE company_id = $1 AND LOWER(status) NOT IN ('won', 'lost')`, [cid]),
    pool.query(`SELECT count(*)::int AS total FROM tasks WHERE company_id = $1 AND LOWER(status) <> 'done'`, [cid]),
    pool.query(`SELECT COALESCE(SUM(balance), 0) AS total FROM customers WHERE company_id = $1 AND balance > 0`, [cid]),
    pool.query(`SELECT COALESCE(SUM(balance), 0) AS total FROM suppliers WHERE company_id = $1 AND balance > 0`, [cid]),
  ]);

  const totalBalance = num(acc.rows[0].total);
  const income = num(flow.rows[0].income);
  const expenses = num(flow.rows[0].expenses);
  const startBalance = totalBalance - (income - expenses);
  const balanceChangePercent = startBalance !== 0
    ? Math.round(((totalBalance - startBalance) / Math.abs(startBalance)) * 1000) / 10
    : (totalBalance !== 0 ? 100 : 0);

  res.json({
    totalBalance,
    balanceChangePercent,
    income,
    expenses,
    sales: num(sales.rows[0].total),
    stockBalance: num(inv.rows[0].total),
    totalProducts: prod.rows[0].total,
    activeDeals: deals.rows[0].total,
    pendingTasks: tasks.rows[0].total,
    customerDebts: num(cust.rows[0].total),
    supplierDebts: num(supp.rows[0].total),
    period,
  });
}));

api.get('/reports/financial', h(async (req, res) => {
  const period = normalizePeriod(req.query.period);
  const { from, to } = periodRange(period);
  const cid = req.companyId;
  const bucket = period === 'year' ? 'month' : 'day';

  const [flow, sales, cogs, series, salesSeries, byCategory] = await Promise.all([
    pool.query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE type = 'INCOME'), 0) AS income,
              COALESCE(SUM(amount) FILTER (WHERE type = 'EXPENSE'), 0) AS expenses
       FROM transactions WHERE company_id = $1 AND transaction_date BETWEEN $2 AND $3`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT COALESCE(SUM(grand_total), 0) AS total, count(*)::int AS n FROM sales
       WHERE company_id = $1 AND status <> 'CANCELLED' AND created_at::date BETWEEN $2 AND $3`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT COALESCE(SUM(si.quantity * si.cost_price), 0) AS total
       FROM sale_items si JOIN sales s ON si.sale_id = s.id
       WHERE s.company_id = $1 AND s.status <> 'CANCELLED' AND s.created_at::date BETWEEN $2 AND $3`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT to_char(date_trunc('${bucket}', transaction_date), 'YYYY-MM-DD') AS date,
              COALESCE(SUM(amount) FILTER (WHERE type = 'INCOME'), 0) AS income,
              COALESCE(SUM(amount) FILTER (WHERE type = 'EXPENSE'), 0) AS expense
       FROM transactions WHERE company_id = $1 AND transaction_date BETWEEN $2 AND $3
       GROUP BY 1 ORDER BY 1`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT to_char(date_trunc('${bucket}', created_at), 'YYYY-MM-DD') AS date, COALESCE(SUM(grand_total), 0) AS amount
       FROM sales WHERE company_id = $1 AND status <> 'CANCELLED' AND created_at::date BETWEEN $2 AND $3
       GROUP BY 1 ORDER BY 1`,
      [cid, from, to]
    ),
    pool.query(
      `SELECT COALESCE(NULLIF(category, ''), 'Прочее') AS category, SUM(amount) AS amount
       FROM transactions WHERE company_id = $1 AND type = 'EXPENSE' AND transaction_date BETWEEN $2 AND $3
       GROUP BY 1 ORDER BY 2 DESC`,
      [cid, from, to]
    ),
  ]);

  const income = num(flow.rows[0].income);
  const expenses = num(flow.rows[0].expenses);
  const revenue = num(sales.rows[0].total);
  const costOfGoods = num(cogs.rows[0].total);
  const grossProfit = revenue - costOfGoods;
  const monthNames = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
  const label = (d) => (bucket === 'month' ? monthNames[parseInt(d.slice(5, 7), 10) - 1] : `${d.slice(8, 10)}.${d.slice(5, 7)}`);

  res.json({
    data: {
      period,
      from,
      to,
      income,
      totalRevenue: income,
      revenue,
      salesCount: sales.rows[0].n,
      expenses,
      totalExpenses: expenses,
      costOfGoods,
      grossProfit,
      netProfit: income - expenses,
      monthlyData: series.rows.map((r) => ({ month: label(r.date), date: r.date, income: num(r.income), expense: num(r.expense) })),
      salesTrend: salesSeries.rows.map((r) => ({ date: r.date, label: label(r.date), amount: num(r.amount) })),
      expensesByCategory: byCategory.rows.map((r) => ({ category: r.category, amount: num(r.amount) })),
    },
  });
}));

// ============================================================================
// FINANCE
// ============================================================================
api.get('/finance/accounts', h(async (req, res) => {
  const result = await pool.query(`SELECT * FROM accounts WHERE company_id = $1 AND is_active ORDER BY created_at ASC, name ASC`, [req.companyId]);
  res.json({ data: out(result.rows) });
}));

api.post('/finance/accounts', requireAdmin, h(async (req, res) => {
  const b = req.body || {};
  if (!str(b.name)) throw new HttpError(400, 'Укажите название счёта');
  const type = ['CASH', 'BANK', 'CARD'].includes(str(b.type).toUpperCase()) ? str(b.type).toUpperCase() : 'CASH';
  const result = await pool.query(
    `INSERT INTO accounts (name, type, account_number, currency, balance, company_id) VALUES ($1, $2, $3, $4, 0, $5) RETURNING *`,
    [str(b.name), type, strOrNull(b.accountNumber), str(b.currency) || 'UZS', req.companyId]
  );
  res.status(201).json({ data: out(result.rows[0]) });
}));

api.get('/finance/categories', h(async (req, res) => {
  const result = await pool.query(`SELECT * FROM expense_categories ORDER BY name ASC`);
  res.json({ data: out(result.rows) });
}));

const TX_SELECT = `
  SELECT t.*, a.name AS account_name, a.type AS account_type, u.full_name AS created_by_name,
         COALESCE(t.transaction_date::timestamp + (t.created_at::time), t.created_at) AS date
  FROM transactions t
  LEFT JOIN accounts a ON t.account_id = a.id
  LEFT JOIN users u ON t.created_by = u.id`;

function txOut(row) {
  const o = out(row);
  o.document_url = fileUrl(row.document_url);
  o.documentUrl = o.document_url;
  o.customerName = row.counterparty_name;
  o.employeeName = row.created_by_name;
  return o;
}

api.get('/finance/transactions', h(async (req, res) => {
  const q = req.query;
  const limit = Math.min(Math.max(parseInt(q.limit, 10) || 50, 1), 200);
  const page = Math.max(parseInt(q.page, 10) || 1, 1);
  const conds = ['t.company_id = $1'];
  const vals = [req.companyId];
  const add = (sql, v) => { vals.push(v); conds.push(sql.replace('?', `$${vals.length}`)); };

  const type = str(q.type).toUpperCase();
  if (type === 'TRANSFER') conds.push(`t.type IN ('TRANSFER_IN', 'TRANSFER_OUT')`);
  else if (type && type !== 'ALL') add('t.type = ?', type);
  if (q.startDate) add('t.transaction_date >= ?', dateOrToday(q.startDate));
  if (q.endDate) add('t.transaction_date <= ?', dateOrToday(q.endDate));
  if (isUuid(q.accountId)) add('t.account_id = ?', q.accountId);
  if (str(q.search)) add(`(t.description ILIKE ? OR t.category ILIKE $${vals.length + 1} OR t.counterparty_name ILIKE $${vals.length + 1})`, `%${str(q.search)}%`);

  const where = conds.join(' AND ');
  const [rows, count] = await Promise.all([
    pool.query(`${TX_SELECT} WHERE ${where} ORDER BY t.transaction_date DESC, t.created_at DESC LIMIT ${limit} OFFSET ${(page - 1) * limit}`, vals),
    pool.query(`SELECT count(*)::int AS total FROM transactions t WHERE ${where}`, vals),
  ]);
  res.json({ data: rows.rows.map(txOut), meta: { total: count.rows[0].total, page, limit } });
}));

async function resolveAccount(client, companyId, accountId, paymentMethod) {
  if (isUuid(accountId)) {
    const byId = await client.query(`SELECT * FROM accounts WHERE id = $1 AND company_id = $2 AND is_active FOR UPDATE`, [accountId, companyId]);
    if (!byId.rows[0]) throw new HttpError(404, 'Счёт не найден');
    return byId.rows[0];
  }
  const method = str(paymentMethod).toLowerCase();
  // Card payments settle to the bank account unless the company keeps a dedicated card account.
  const order = method === 'card' ? ['CARD', 'BANK', 'CASH'] : method === 'bank' ? ['BANK', 'CASH'] : ['CASH', 'BANK'];
  for (const type of order) {
    const found = await client.query(
      `SELECT * FROM accounts WHERE company_id = $1 AND type = $2 AND is_active ORDER BY created_at ASC LIMIT 1 FOR UPDATE`,
      [companyId, type]
    );
    if (found.rows[0]) return found.rows[0];
  }
  throw new HttpError(400, 'В организации нет активных счетов');
}

// The only place that writes a transaction: the row and the account balance change together.
async function postTransaction(client, { companyId, userId, account, type, amount, category, description, counterparty,
  paymentMethod, date, referenceType, referenceId, documentUrl, documentName }) {
  const sign = type === 'INCOME' || type === 'TRANSFER_IN' ? 1 : -1;
  const inserted = await client.query(
    `INSERT INTO transactions (company_id, account_id, type, amount, category, description, counterparty_name, payment_method,
                               reference_type, reference_id, document_url, document_name, created_by, transaction_date)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) RETURNING id`,
    [companyId, account.id, type, amount, category, description, counterparty || null, paymentMethod || null,
      referenceType || null, uuidOrNull(referenceId), documentUrl || null, documentName || null, userId, date]
  );
  await client.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [sign * amount, account.id]);
  const full = await client.query(`${TX_SELECT} WHERE t.id = $1`, [inserted.rows[0].id]);
  return full.rows[0];
}

function relativeUploadPath(url) {
  if (!url) return null;
  const s = String(url);
  const i = s.indexOf('/uploads/');
  return i >= 0 ? s.slice(i) : null;
}

const methodOf = (b) => (['cash', 'bank', 'card'].includes(str(b.paymentMethod).toLowerCase()) ? str(b.paymentMethod).toLowerCase() : 'cash');

api.post('/finance/transactions/income', h(async (req, res) => {
  const b = req.body || {};
  const amount = requirePositive(b.amount, 'Сумма поступления');
  const customerName = str(b.customerName);
  const row = await tx(async (client) => {
    const account = await resolveAccount(client, req.companyId, b.accountId, b.paymentMethod);
    let customerId = null;
    if (isUuid(b.customerId)) {
      const c = await client.query(`UPDATE customers SET balance = balance - $1 WHERE id = $2 AND company_id = $3 RETURNING id`, [amount, b.customerId, req.companyId]);
      if (!c.rows[0]) throw new HttpError(404, 'Клиент не найден');
      customerId = b.customerId;
    }
    return postTransaction(client, {
      companyId: req.companyId, userId: req.user.id, account, type: 'INCOME', amount,
      category: str(b.category) || 'Поступление', description: str(b.description) || (customerName ? `Поступление: ${customerName}` : 'Поступление средств'),
      counterparty: customerName, paymentMethod: methodOf(b), date: dateOrToday(b.date),
      referenceType: customerId ? 'CUSTOMER' : null, referenceId: customerId,
      documentUrl: relativeUploadPath(b.documentUrl), documentName: strOrNull(b.documentName),
    });
  });
  await notify(req.user.id, 'Поступление средств', `Зафиксирован доход: ${money(amount)} сум${row.counterparty_name ? ` — ${row.counterparty_name}` : ''}`, 'FINANCE', row.id);
  res.status(201).json({ data: txOut(row) });
}));

api.post('/finance/transactions/expense', h(async (req, res) => {
  const b = req.body || {};
  const amount = requirePositive(b.amount, 'Сумма расхода');
  const counterparty = str(b.supplierName || b.employeeName);
  const row = await tx(async (client) => {
    const account = await resolveAccount(client, req.companyId, b.accountId, b.paymentMethod);
    let supplierId = null;
    if (isUuid(b.supplierId)) {
      const s = await client.query(`UPDATE suppliers SET balance = balance - $1 WHERE id = $2 AND company_id = $3 RETURNING id`, [amount, b.supplierId, req.companyId]);
      if (!s.rows[0]) throw new HttpError(404, 'Поставщик не найден');
      supplierId = b.supplierId;
    }
    return postTransaction(client, {
      companyId: req.companyId, userId: req.user.id, account, type: 'EXPENSE', amount,
      category: str(b.category) || 'Прочее', description: str(b.description) || (counterparty ? `Расход: ${counterparty}` : 'Расход средств'),
      counterparty, paymentMethod: methodOf(b), date: dateOrToday(b.date),
      referenceType: supplierId ? 'SUPPLIER' : null, referenceId: supplierId,
      documentUrl: relativeUploadPath(b.documentUrl), documentName: strOrNull(b.documentName),
    });
  });
  await notify(req.user.id, 'Расход средств', `Зафиксирован расход: ${money(amount)} сум (${row.category})`, 'FINANCE', row.id);
  res.status(201).json({ data: txOut(row) });
}));

api.post('/finance/transactions/transfer', h(async (req, res) => {
  const b = req.body || {};
  const amount = requirePositive(b.amount, 'Сумма перевода');
  if (!isUuid(b.fromAccountId) || !isUuid(b.toAccountId)) throw new HttpError(400, 'Выберите счёт списания и счёт зачисления');
  if (b.fromAccountId === b.toAccountId) throw new HttpError(400, 'Счета списания и зачисления должны различаться');
  const row = await tx(async (client) => {
    // Lock both accounts in a stable order so two opposite transfers cannot deadlock.
    const [first, second] = [b.fromAccountId, b.toAccountId].sort();
    await client.query(`SELECT id FROM accounts WHERE id IN ($1, $2) AND company_id = $3 ORDER BY id FOR UPDATE`, [first, second, req.companyId]);
    const from = await resolveAccount(client, req.companyId, b.fromAccountId);
    const to = await resolveAccount(client, req.companyId, b.toAccountId);
    if (num(from.balance) < amount) throw new HttpError(400, 'Недостаточно средств на счёте списания');
    const common = { companyId: req.companyId, userId: req.user.id, amount, date: dateOrToday(b.date), referenceType: 'TRANSFER' };
    const description = str(b.description) || `Перевод: ${from.name} → ${to.name}`;
    await postTransaction(client, { ...common, account: from, type: 'TRANSFER_OUT', category: 'Перевод со счёта', description, counterparty: to.name });
    return postTransaction(client, { ...common, account: to, type: 'TRANSFER_IN', category: 'Перевод на счёт', description, counterparty: from.name });
  });
  res.status(201).json({ data: txOut(row) });
}));

api.delete('/finance/transactions/:id', requireAdmin, h(async (req, res) => {
  const removed = await tx(async (client) => {
    const found = await client.query(`SELECT * FROM transactions WHERE id = $1 AND company_id = $2 FOR UPDATE`, [uuidOrNull(req.params.id), req.companyId]);
    const t = found.rows[0];
    if (!t) throw new HttpError(404, 'Операция не найдена');
    if (t.reference_type === 'SALE' || t.reference_type === 'TRANSFER') throw new HttpError(400, 'Эту операцию нельзя удалить отдельно от связанного документа');
    const sign = t.type === 'INCOME' ? -1 : 1;
    await client.query(`UPDATE accounts SET balance = balance + $1 WHERE id = $2`, [sign * num(t.amount), t.account_id]);
    if (t.reference_type === 'CUSTOMER' && t.reference_id) await client.query(`UPDATE customers SET balance = balance + $1 WHERE id = $2`, [t.amount, t.reference_id]);
    if (t.reference_type === 'SUPPLIER' && t.reference_id) await client.query(`UPDATE suppliers SET balance = balance + $1 WHERE id = $2`, [t.amount, t.reference_id]);
    await client.query(`DELETE FROM transactions WHERE id = $1`, [t.id]);
    return t;
  });
  removeUploadedFile(removed.document_url);
  res.json({ success: true });
}));

api.post('/finance/debts/pay', h(async (req, res) => {
  const b = req.body || {};
  const amount = requirePositive(b.amount, 'Сумма');
  if (!isUuid(b.debtId)) throw new HttpError(400, 'Не указана задолженность');
  const payable = ['payable', 'supplier'].includes(str(b.type).toLowerCase());
  const row = await tx(async (client) => {
    const table = payable ? 'suppliers' : 'customers';
    const party = await client.query(`SELECT * FROM ${table} WHERE id = $1 AND company_id = $2 FOR UPDATE`, [b.debtId, req.companyId]);
    if (!party.rows[0]) throw new HttpError(404, 'Задолженность не найдена');
    if (amount > num(party.rows[0].balance)) throw new HttpError(400, 'Сумма оплаты больше остатка задолженности');
    await client.query(`UPDATE ${table} SET balance = balance - $1 WHERE id = $2`, [amount, b.debtId]);
    const account = await resolveAccount(client, req.companyId, b.accountId, b.paymentMethod);
    return postTransaction(client, {
      companyId: req.companyId, userId: req.user.id, account, type: payable ? 'EXPENSE' : 'INCOME', amount,
      category: 'Погашение задолженности', description: str(b.description) || `Оплата по задолженности: ${party.rows[0].name}`,
      counterparty: party.rows[0].name, paymentMethod: methodOf(b), date: dateOrToday(b.date),
      referenceType: payable ? 'SUPPLIER_DEBT' : 'CUSTOMER_DEBT', referenceId: b.debtId,
      documentUrl: relativeUploadPath(b.documentUrl), documentName: strOrNull(b.documentName),
    });
  });
  await notify(req.user.id, payable ? 'Оплата кредиторской задолженности' : 'Погашение дебиторской задолженности', `Оплата задолженности: ${money(amount)} сум`, 'FINANCE', row.id);
  res.status(201).json({ data: txOut(row) });
}));

api.get('/finance/customer-debts', h(async (req, res) => {
  const result = await pool.query(
    `SELECT c.id, c.id AS customer_id, c.name AS customer_name, c.phone, c.balance AS amount, c.balance AS total_amount,
            COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.company_id = c.company_id
                      AND t.reference_type = 'CUSTOMER_DEBT' AND t.reference_id = c.id), 0) AS paid_amount,
            NULL::date AS due_date, 'pending' AS status, 'receivable' AS type
     FROM customers c WHERE c.company_id = $1 AND c.balance > 0 ORDER BY c.balance DESC`,
    [req.companyId]
  );
  res.json({ data: out(result.rows) });
}));

api.get('/finance/supplier-debts', h(async (req, res) => {
  const result = await pool.query(
    `SELECT s.id, s.id AS supplier_id, s.name AS supplier_name, s.phone, s.balance AS amount, s.balance AS total_amount,
            COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.company_id = s.company_id
                      AND t.reference_type = 'SUPPLIER_DEBT' AND t.reference_id = s.id), 0) AS paid_amount,
            NULL::date AS due_date, 'pending' AS status, 'payable' AS type
     FROM suppliers s WHERE s.company_id = $1 AND s.balance > 0 ORDER BY s.balance DESC`,
    [req.companyId]
  );
  res.json({ data: out(result.rows) });
}));

// ============================================================================
// INVENTORY & PRODUCTS
// ============================================================================
const PRODUCT_SELECT = `
  SELECT p.*, c.name AS category_name,
         COALESCE(i.quantity, 0) AS quantity, COALESCE(i.quantity, 0) AS current_stock,
         COALESCE(i.average_cost, p.purchase_price) AS avg_cost,
         (COALESCE(i.quantity, 0) <= p.min_stock_level) AS is_low_stock
  FROM products p
  LEFT JOIN product_categories c ON p.category_id = c.id
  LEFT JOIN (SELECT product_id, SUM(quantity) AS quantity,
                    CASE WHEN SUM(quantity) > 0 THEN SUM(quantity * average_cost) / SUM(quantity) ELSE MAX(average_cost) END AS average_cost
             FROM inventory GROUP BY product_id) i ON p.id = i.product_id`;

async function defaultWarehouse(client, companyId) {
  const found = await client.query(`SELECT id FROM warehouses WHERE company_id = $1 ORDER BY is_default DESC, created_at ASC LIMIT 1`, [companyId]);
  if (found.rows[0]) return found.rows[0].id;
  const created = await client.query(`INSERT INTO warehouses (name, is_default, company_id) VALUES ('Основной склад', TRUE, $1) RETURNING id`, [companyId]);
  return created.rows[0].id;
}

// The only place that changes stock: the inventory row and its movement record change together.
async function moveStock(client, { companyId, userId, productId, warehouseId, delta, type, unitCost, referenceType, referenceId, reason }) {
  const product = await client.query(`SELECT id, name, unit, purchase_price FROM products WHERE id = $1 AND company_id = $2 AND is_active`, [productId, companyId]);
  if (!product.rows[0]) throw new HttpError(404, 'Товар не найден');
  await client.query(
    `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost) VALUES ($1, $2, 0, $3)
     ON CONFLICT (product_id, warehouse_id) DO NOTHING`,
    [productId, warehouseId, product.rows[0].purchase_price]
  );
  const inv = await client.query(`SELECT quantity, average_cost FROM inventory WHERE product_id = $1 AND warehouse_id = $2 FOR UPDATE`, [productId, warehouseId]);
  const curQty = num(inv.rows[0].quantity);
  const curAvg = num(inv.rows[0].average_cost);
  const newQty = Math.round((curQty + delta) * 100) / 100;
  if (newQty < 0) {
    throw new HttpError(400, `Недостаточно товара «${product.rows[0].name}» на складе: доступно ${curQty} ${product.rows[0].unit}`);
  }
  let newAvg = curAvg;
  if (delta > 0 && unitCost != null && unitCost > 0) {
    newAvg = newQty > 0 ? Math.round(((curQty * curAvg + delta * unitCost) / newQty) * 100) / 100 : unitCost;
  }
  await client.query(
    `UPDATE inventory SET quantity = $1, average_cost = $2, last_updated_at = CURRENT_TIMESTAMP WHERE product_id = $3 AND warehouse_id = $4`,
    [newQty, newAvg, productId, warehouseId]
  );
  await client.query(
    `INSERT INTO stock_movements (company_id, product_id, warehouse_id, type, quantity, unit_cost, balance_after, reference_type, reference_id, reason, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
    [companyId, productId, warehouseId, type, Math.abs(delta), unitCost != null ? unitCost : curAvg, newQty, referenceType || 'MANUAL', uuidOrNull(referenceId), reason || null, userId]
  );
  return { quantity: newQty, averageCost: newAvg, previousAverageCost: curAvg };
}

api.get('/inventory/products', h(async (req, res) => {
  const q = req.query;
  const conds = ['p.company_id = $1', 'p.is_active'];
  const vals = [req.companyId];
  if (str(q.search)) {
    vals.push(`%${str(q.search)}%`);
    conds.push(`(p.name ILIKE $${vals.length} OR p.sku ILIKE $${vals.length} OR p.barcode ILIKE $${vals.length})`);
  }
  if (isUuid(q.categoryId)) {
    vals.push(q.categoryId);
    conds.push(`p.category_id = $${vals.length}`);
  }
  if (q.lowStock === 'true' || q.filter === 'low') conds.push(`COALESCE(i.quantity, 0) <= p.min_stock_level`);
  if (q.filter === 'out') conds.push(`COALESCE(i.quantity, 0) <= 0`);
  const limit = Math.min(Math.max(parseInt(q.limit, 10) || 200, 1), 500);
  const page = Math.max(parseInt(q.page, 10) || 1, 1);
  const result = await pool.query(
    `${PRODUCT_SELECT} WHERE ${conds.join(' AND ')} ORDER BY p.created_at DESC LIMIT ${limit} OFFSET ${(page - 1) * limit}`,
    vals
  );
  res.json({ data: out(result.rows) });
}));

api.get('/inventory/alerts/low-stock', h(async (req, res) => {
  const result = await pool.query(
    `${PRODUCT_SELECT} WHERE p.company_id = $1 AND p.is_active AND COALESCE(i.quantity, 0) <= p.min_stock_level ORDER BY p.name`,
    [req.companyId]
  );
  res.json({ data: out(result.rows) });
}));

api.get('/inventory/categories', h(async (req, res) => {
  const result = await pool.query(`SELECT * FROM product_categories WHERE company_id = $1 ORDER BY name ASC`, [req.companyId]);
  res.json({ data: out(result.rows) });
}));

api.post('/inventory/categories', h(async (req, res) => {
  const name = str(req.body && req.body.name);
  if (!name) throw new HttpError(400, 'Укажите название категории');
  const existing = await pool.query(`SELECT * FROM product_categories WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [req.companyId, name]);
  if (existing.rows[0]) return res.json({ data: out(existing.rows[0]) });
  const result = await pool.query(`INSERT INTO product_categories (name, company_id) VALUES ($1, $2) RETURNING *`, [name, req.companyId]);
  res.status(201).json({ data: out(result.rows[0]) });
}));

api.get('/inventory/warehouses', h(async (req, res) => {
  const result = await pool.query(`SELECT * FROM warehouses WHERE company_id = $1 ORDER BY is_default DESC, created_at ASC`, [req.companyId]);
  res.json({ data: out(result.rows) });
}));

api.get('/inventory/movements', h(async (req, res) => {
  const vals = [req.companyId];
  let where = 'p.company_id = $1';
  if (isUuid(req.query.productId)) {
    vals.push(req.query.productId);
    where += ' AND m.product_id = $2';
  }
  const result = await pool.query(
    `SELECT m.*, p.name AS product_name, u.full_name AS created_by_name, m.reason AS notes
     FROM stock_movements m JOIN products p ON p.id = m.product_id LEFT JOIN users u ON u.id = m.created_by
     WHERE ${where} ORDER BY m.created_at DESC LIMIT 200`,
    vals
  );
  res.json({ data: out(result.rows) });
}));

api.get('/inventory/levels', h(async (req, res) => {
  const result = await pool.query(`${PRODUCT_SELECT} WHERE p.company_id = $1 AND p.is_active ORDER BY p.name`, [req.companyId]);
  res.json({ data: out(result.rows) });
}));

async function resolveCategory(client, companyId, body) {
  if (isUuid(body.categoryId)) {
    const c = await client.query(`SELECT id FROM product_categories WHERE id = $1 AND company_id = $2`, [body.categoryId, companyId]);
    if (c.rows[0]) return c.rows[0].id;
  }
  const name = str(body.categoryName || body.category);
  if (!name) return null;
  const existing = await client.query(`SELECT id FROM product_categories WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [companyId, name]);
  if (existing.rows[0]) return existing.rows[0].id;
  const created = await client.query(`INSERT INTO product_categories (name, company_id) VALUES ($1, $2) RETURNING id`, [name, companyId]);
  return created.rows[0].id;
}

async function getProduct(db, companyId, id) {
  const result = await db.query(`${PRODUCT_SELECT} WHERE p.id = $1 AND p.company_id = $2`, [uuidOrNull(id), companyId]);
  return result.rows[0] || null;
}

api.get('/inventory/products/:id', h(async (req, res) => {
  const product = await getProduct(pool, req.companyId, req.params.id);
  if (!product || !product.is_active) throw new HttpError(404, 'Товар не найден');
  res.json({ data: out(product) });
}));

api.post('/inventory/products', h(async (req, res) => {
  const b = req.body || {};
  if (!str(b.name)) throw new HttpError(400, 'Укажите название товара');
  const sellingPrice = num(b.sellingPrice != null ? b.sellingPrice : b.price);
  const purchasePrice = num(b.purchasePrice != null ? b.purchasePrice : b.costPrice);
  if (sellingPrice < 0 || purchasePrice < 0) throw new HttpError(400, 'Цена не может быть отрицательной');
  const initialStock = num(b.initialStock != null ? b.initialStock : (b.currentStock != null ? b.currentStock : b.quantity));
  if (initialStock < 0) throw new HttpError(400, 'Количество не может быть отрицательным');

  const product = await tx(async (client) => {
    const sku = str(b.sku) || `SKU-${Date.now().toString(36).toUpperCase()}${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
    const dup = await client.query(`SELECT 1 FROM products WHERE company_id = $1 AND is_active AND LOWER(sku) = LOWER($2)`, [req.companyId, sku]);
    if (dup.rows[0]) throw new HttpError(400, `Товар с артикулом «${sku}» уже существует`);
    const categoryId = await resolveCategory(client, req.companyId, b);
    const inserted = await client.query(
      `INSERT INTO products (company_id, name, sku, category_id, selling_price, purchase_price, unit, min_stock_level, description, barcode, image_url, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, TRUE) RETURNING id`,
      [req.companyId, str(b.name), sku, categoryId, sellingPrice, purchasePrice, str(b.unit) || 'шт',
        Math.max(0, Math.round(num(b.minStockLevel, 5))), str(b.description), strOrNull(b.barcode), strOrNull(b.imageUrl)]
    );
    const warehouseId = await defaultWarehouse(client, req.companyId);
    await client.query(
      `INSERT INTO inventory (product_id, warehouse_id, quantity, average_cost) VALUES ($1, $2, 0, $3) ON CONFLICT DO NOTHING`,
      [inserted.rows[0].id, warehouseId, purchasePrice]
    );
    if (initialStock > 0) {
      await moveStock(client, {
        companyId: req.companyId, userId: req.user.id, productId: inserted.rows[0].id, warehouseId, delta: initialStock,
        type: 'INCOMING', unitCost: purchasePrice, referenceType: 'MANUAL', reason: 'Начальный остаток',
      });
    }
    return getProduct(client, req.companyId, inserted.rows[0].id);
  });
  res.status(201).json({ data: out(product) });
}));

const handleUpdateProduct = h(async (req, res) => {
  const b = req.body || {};
  const product = await tx(async (client) => {
    const current = await client.query(`SELECT * FROM products WHERE id = $1 AND company_id = $2 AND is_active FOR UPDATE`, [uuidOrNull(req.params.id), req.companyId]);
    if (!current.rows[0]) throw new HttpError(404, 'Товар не найден');
    const sets = [];
    const vals = [req.params.id];
    const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
    if (b.name !== undefined) {
      if (!str(b.name)) throw new HttpError(400, 'Укажите название товара');
      set('name', str(b.name));
    }
    if (b.sku !== undefined && str(b.sku) && str(b.sku).toLowerCase() !== String(current.rows[0].sku).toLowerCase()) {
      const dup = await client.query(`SELECT 1 FROM products WHERE company_id = $1 AND is_active AND LOWER(sku) = LOWER($2) AND id <> $3`, [req.companyId, str(b.sku), req.params.id]);
      if (dup.rows[0]) throw new HttpError(400, `Товар с артикулом «${str(b.sku)}» уже существует`);
      set('sku', str(b.sku));
    }
    const selling = b.sellingPrice !== undefined ? b.sellingPrice : b.price;
    const purchase = b.purchasePrice !== undefined ? b.purchasePrice : b.costPrice;
    if (selling !== undefined) {
      if (num(selling) < 0) throw new HttpError(400, 'Цена не может быть отрицательной');
      set('selling_price', num(selling));
    }
    if (purchase !== undefined) {
      if (num(purchase) < 0) throw new HttpError(400, 'Цена не может быть отрицательной');
      set('purchase_price', num(purchase));
    }
    if (b.unit !== undefined && str(b.unit)) set('unit', str(b.unit));
    if (b.minStockLevel !== undefined) set('min_stock_level', Math.max(0, Math.round(num(b.minStockLevel))));
    if (b.description !== undefined) set('description', str(b.description));
    if (b.barcode !== undefined) set('barcode', strOrNull(b.barcode));
    if (b.imageUrl !== undefined) set('image_url', strOrNull(b.imageUrl));
    if (b.categoryId !== undefined || b.categoryName !== undefined || b.category !== undefined) set('category_id', await resolveCategory(client, req.companyId, b));
    if (sets.length > 0) await client.query(`UPDATE products SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, vals);
    return getProduct(client, req.companyId, req.params.id);
  });
  res.json({ data: out(product) });
});
api.patch('/inventory/products/:id', handleUpdateProduct);
api.put('/inventory/products/:id', handleUpdateProduct);

api.delete('/inventory/products/:id', h(async (req, res) => {
  const result = await pool.query(
    `UPDATE products SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND company_id = $2 AND is_active RETURNING id`,
    [uuidOrNull(req.params.id), req.companyId]
  );
  if (!result.rows[0]) throw new HttpError(404, 'Товар не найден');
  res.json({ success: true });
}));

api.post('/inventory/adjust', h(async (req, res) => {
  const b = req.body || {};
  if (!isUuid(b.productId)) throw new HttpError(400, 'Выберите товар');
  const kind = str(b.type).toLowerCase();
  const quantity = num(b.quantity, NaN);
  if (!Number.isFinite(quantity) || quantity < 0) throw new HttpError(400, 'Укажите корректное количество');
  const reason = str(b.notes || b.reason);

  const product = await tx(async (client) => {
    const warehouseId = await defaultWarehouse(client, req.companyId);
    let delta;
    let type;
    if (['set', 'correction', 'inventory', 'adjustment'].includes(kind)) {
      const cur = await client.query(`SELECT COALESCE(SUM(quantity), 0) AS q FROM inventory WHERE product_id = $1 AND warehouse_id = $2`, [b.productId, warehouseId]);
      delta = Math.round((quantity - num(cur.rows[0].q)) * 100) / 100;
      type = 'ADJUSTMENT';
    } else if (['out', 'outgoing', 'decrease', 'remove', 'writeoff', 'write_off', 'subtract', 'minus'].includes(kind)) {
      delta = -quantity;
      type = 'OUTGOING';
    } else {
      delta = quantity;
      type = 'INCOMING';
    }
    if (delta === 0) throw new HttpError(400, 'Количество не изменилось');
    await moveStock(client, {
      companyId: req.companyId, userId: req.user.id, productId: b.productId, warehouseId, delta, type,
      unitCost: delta > 0 && b.unitCost != null ? num(b.unitCost) : null, referenceType: 'MANUAL',
      reason: reason || (type === 'INCOMING' ? 'Ручное оприходование' : type === 'OUTGOING' ? 'Ручное списание' : 'Инвентаризация'),
    });
    return getProduct(client, req.companyId, b.productId);
  });
  res.status(201).json({ data: out(product) });
}));

// ============================================================================
// INCOMING SHIPMENTS
// ============================================================================
function shipmentOut(row, items) {
  const o = out(row);
  o.invoiceNumber = row.shipment_number;
  o.totalCost = num(row.total_amount);
  o.responsibleEmployee = row.created_by_name || null;
  if (items) {
    o.items = items.map((it) => ({ ...out(it), unitPrice: num(it.purchase_price), totalPrice: num(it.total_amount) }));
  }
  return o;
}

const SHIPMENT_SELECT = `
  SELECT s.*, sup.name AS supplier_name, u.full_name AS created_by_name
  FROM incoming_shipments s
  LEFT JOIN suppliers sup ON s.supplier_id = sup.id
  LEFT JOIN users u ON s.created_by = u.id`;

async function shipmentItems(db, shipmentId) {
  const r = await db.query(
    `SELECT isi.*, p.name AS product_name FROM incoming_shipment_items isi LEFT JOIN products p ON isi.product_id = p.id WHERE isi.shipment_id = $1`,
    [shipmentId]
  );
  return r.rows;
}

api.get('/shipments', h(async (req, res) => {
  const conds = ['s.company_id = $1'];
  const vals = [req.companyId];
  const status = str(req.query.status).toUpperCase();
  if (status && status !== 'ALL') {
    vals.push(status);
    conds.push(`UPPER(s.status) = $${vals.length}`);
  }
  if (str(req.query.search)) {
    vals.push(`%${str(req.query.search)}%`);
    conds.push(`(s.shipment_number ILIKE $${vals.length} OR sup.name ILIKE $${vals.length})`);
  }
  const result = await pool.query(`${SHIPMENT_SELECT} WHERE ${conds.join(' AND ')} ORDER BY s.created_at DESC LIMIT 300`, vals);
  res.json({ data: result.rows.map((r) => shipmentOut(r)) });
}));

api.get('/shipments/:id', h(async (req, res) => {
  const result = await pool.query(`${SHIPMENT_SELECT} WHERE s.id = $1 AND s.company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Поставка не найдена');
  res.json({ data: shipmentOut(result.rows[0], await shipmentItems(pool, req.params.id)) });
}));

async function receiveShipment(client, req, shipment) {
  const items = await shipmentItems(client, shipment.id);
  const warehouseId = shipment.warehouse_id || await defaultWarehouse(client, req.companyId);
  for (const it of items) {
    await moveStock(client, {
      companyId: req.companyId, userId: req.user.id, productId: it.product_id, warehouseId, delta: num(it.quantity),
      type: 'INCOMING', unitCost: num(it.purchase_price), referenceType: 'SHIPMENT', referenceId: shipment.id,
      reason: `Поступление по накладной ${shipment.shipment_number}`,
    });
    await client.query(`UPDATE incoming_shipment_items SET received_quantity = quantity WHERE id = $1`, [it.id]);
  }
  if (shipment.supplier_id) {
    await client.query(`UPDATE suppliers SET balance = balance + $1 WHERE id = $2`, [num(shipment.total_amount) + num(shipment.additional_costs), shipment.supplier_id]);
  }
  await client.query(`UPDATE incoming_shipments SET status = 'RECEIVED', received_date = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [shipment.id]);
}

api.post('/shipments', h(async (req, res) => {
  const b = req.body || {};
  const rawItems = Array.isArray(b.items) ? b.items : [];
  if (rawItems.length === 0) throw new HttpError(400, 'Добавьте хотя бы один товар в поставку');
  const pending = str(b.status).toLowerCase() === 'pending';

  const shipment = await tx(async (client) => {
    let supplierId = null;
    if (isUuid(b.supplierId)) {
      const s = await client.query(`SELECT id FROM suppliers WHERE id = $1 AND company_id = $2`, [b.supplierId, req.companyId]);
      if (!s.rows[0]) throw new HttpError(404, 'Поставщик не найден');
      supplierId = b.supplierId;
    } else if (str(b.supplierName)) {
      const existing = await client.query(`SELECT id FROM suppliers WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [req.companyId, str(b.supplierName)]);
      supplierId = existing.rows[0]
        ? existing.rows[0].id
        : (await client.query(`INSERT INTO suppliers (name, company_id) VALUES ($1, $2) RETURNING id`, [str(b.supplierName), req.companyId])).rows[0].id;
    }

    const items = rawItems.map((it) => {
      const productId = it.productId || it.product_id;
      if (!isUuid(productId)) throw new HttpError(400, 'В поставке указан неизвестный товар');
      const quantity = requirePositive(it.quantity, 'Количество товара');
      const price = num(it.unitPrice != null ? it.unitPrice : (it.purchasePrice != null ? it.purchasePrice : it.price));
      if (price < 0) throw new HttpError(400, 'Цена не может быть отрицательной');
      return { productId, quantity, price, total: Math.round(quantity * price * 100) / 100 };
    });
    const total = items.reduce((s, it) => s + it.total, 0);
    const warehouseId = await defaultWarehouse(client, req.companyId);
    const number = str(b.invoiceNumber) || `ПСТ-${Date.now().toString().slice(-8)}`;
    const dup = await client.query(`SELECT 1 FROM incoming_shipments WHERE company_id = $1 AND shipment_number = $2`, [req.companyId, number]);
    if (dup.rows[0]) throw new HttpError(400, `Поставка с номером «${number}» уже существует`);

    const inserted = await client.query(
      `INSERT INTO incoming_shipments (company_id, shipment_number, supplier_id, warehouse_id, status, expected_date, total_amount, additional_costs, notes, created_by)
       VALUES ($1, $2, $3, $4, 'PENDING', $5, $6, $7, $8, $9) RETURNING *`,
      [req.companyId, number, supplierId, warehouseId, dateOrToday(b.expectedDate), total, Math.max(0, num(b.additionalCosts)), strOrNull(b.notes), req.user.id]
    );
    for (const it of items) {
      const p = await client.query(`SELECT 1 FROM products WHERE id = $1 AND company_id = $2 AND is_active`, [it.productId, req.companyId]);
      if (!p.rows[0]) throw new HttpError(404, 'Товар из поставки не найден');
      await client.query(
        `INSERT INTO incoming_shipment_items (shipment_id, product_id, quantity, purchase_price, total_amount) VALUES ($1, $2, $3, $4, $5)`,
        [inserted.rows[0].id, it.productId, it.quantity, it.price, it.total]
      );
    }
    if (!pending) await receiveShipment(client, req, inserted.rows[0]);
    const full = await client.query(`${SHIPMENT_SELECT} WHERE s.id = $1`, [inserted.rows[0].id]);
    return shipmentOut(full.rows[0], await shipmentItems(client, inserted.rows[0].id));
  });
  await notify(req.user.id, 'Новая поставка', `Поставка №${shipment.shipment_number} на сумму ${money(shipment.totalCost)} сум`, 'SHIPMENT', shipment.id);
  res.status(201).json({ data: shipment });
}));

api.post('/shipments/:id/confirm', h(async (req, res) => {
  const shipment = await tx(async (client) => {
    const found = await client.query(`SELECT * FROM incoming_shipments WHERE id = $1 AND company_id = $2 FOR UPDATE`, [uuidOrNull(req.params.id), req.companyId]);
    if (!found.rows[0]) throw new HttpError(404, 'Поставка не найдена');
    if (found.rows[0].status === 'RECEIVED') throw new HttpError(400, 'Поставка уже принята на склад');
    if (found.rows[0].status === 'CANCELLED') throw new HttpError(400, 'Поставка отменена');
    await receiveShipment(client, req, found.rows[0]);
    const full = await client.query(`${SHIPMENT_SELECT} WHERE s.id = $1`, [found.rows[0].id]);
    return shipmentOut(full.rows[0], await shipmentItems(client, found.rows[0].id));
  });
  res.json({ data: shipment });
}));

// ============================================================================
// SALES
// ============================================================================
const SALE_SELECT = `
  SELECT s.*, c.name AS customer_name, u.full_name AS manager_name
  FROM sales s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN users u ON s.created_by = u.id`;

async function saleDetails(db, row) {
  const [items, payments] = await Promise.all([
    db.query(`SELECT si.*, p.name AS product_name FROM sale_items si LEFT JOIN products p ON si.product_id = p.id WHERE si.sale_id = $1`, [row.id]),
    db.query(`SELECT id, amount, payment_method, payment_method AS method, transaction_date AS payment_date, created_at
              FROM transactions WHERE reference_type = 'SALE' AND reference_id = $1 ORDER BY created_at ASC`, [row.id]),
  ]);
  return saleOut(row, items.rows, payments.rows);
}

function saleOut(row, items, payments) {
  const o = out(row);
  o.totalAmount = num(row.grand_total);
  o.paymentStatus = String(row.payment_status || 'UNPAID').toLowerCase();
  o.status = o.paymentStatus;
  o.saleStatus = row.status;
  o.managerName = row.manager_name || null;
  if (items) o.items = items.map((it) => ({ ...out(it), price: num(it.unit_price), totalPrice: num(it.total_amount) }));
  if (payments) o.payments = payments.map((p) => ({ ...out(p), date: p.payment_date }));
  return o;
}

api.get('/sales', h(async (req, res) => {
  const conds = ['s.company_id = $1'];
  const vals = [req.companyId];
  const status = str(req.query.status || req.query.paymentStatus).toUpperCase();
  if (['PAID', 'PARTIAL', 'UNPAID'].includes(status)) {
    vals.push(status);
    conds.push(`s.payment_status = $${vals.length}`);
  }
  if (str(req.query.search)) {
    vals.push(`%${str(req.query.search)}%`);
    conds.push(`(s.sale_number ILIKE $${vals.length} OR c.name ILIKE $${vals.length})`);
  }
  const result = await pool.query(`${SALE_SELECT} WHERE ${conds.join(' AND ')} ORDER BY s.created_at DESC LIMIT 300`, vals);
  res.json({ data: result.rows.map((r) => saleOut(r)) });
}));

api.get('/sales/:id', h(async (req, res) => {
  const result = await pool.query(`${SALE_SELECT} WHERE s.id = $1 AND s.company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Продажа не найдена');
  res.json({ data: await saleDetails(pool, result.rows[0]) });
}));

async function resolveCustomer(client, companyId, body) {
  if (isUuid(body.customerId)) {
    const c = await client.query(`SELECT id FROM customers WHERE id = $1 AND company_id = $2`, [body.customerId, companyId]);
    if (!c.rows[0]) throw new HttpError(404, 'Клиент не найден');
    return c.rows[0].id;
  }
  const name = str(body.customerName);
  if (!name) return null;
  const existing = await client.query(`SELECT id FROM customers WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [companyId, name]);
  if (existing.rows[0]) return existing.rows[0].id;
  return (await client.query(`INSERT INTO customers (name, company_id) VALUES ($1, $2) RETURNING id`, [name, companyId])).rows[0].id;
}

api.post('/sales', h(async (req, res) => {
  const b = req.body || {};
  const rawItems = Array.isArray(b.items) ? b.items : [];
  if (rawItems.length === 0) throw new HttpError(400, 'Добавьте хотя бы один товар в продажу');

  const sale = await tx(async (client) => {
    const items = rawItems.map((it) => {
      const productId = it.productId || it.product_id;
      if (!isUuid(productId)) throw new HttpError(400, 'В продаже указан неизвестный товар');
      const quantity = requirePositive(it.quantity, 'Количество товара');
      const price = num(it.price != null ? it.price : it.unitPrice);
      if (price < 0) throw new HttpError(400, 'Цена не может быть отрицательной');
      return { productId, quantity, price, total: Math.round(quantity * price * 100) / 100 };
    });
    const subtotal = items.reduce((s, it) => s + it.total, 0);
    const discount = Math.min(Math.max(0, num(b.discount)), subtotal);
    const grandTotal = Math.round((subtotal - discount) * 100) / 100;
    const paid = Math.max(0, num(b.paidAmount));
    if (paid > grandTotal) throw new HttpError(400, 'Оплаченная сумма больше суммы продажи');
    const customerId = await resolveCustomer(client, req.companyId, b);
    if (paid < grandTotal && !customerId) throw new HttpError(400, 'Для продажи в долг укажите клиента');

    const warehouseId = await defaultWarehouse(client, req.companyId);
    const number = `ПРД-${Date.now().toString().slice(-8)}${crypto.randomBytes(1).toString('hex').toUpperCase()}`;
    const paymentStatus = paid >= grandTotal ? 'PAID' : paid > 0 ? 'PARTIAL' : 'UNPAID';
    const method = methodOf(b);
    const inserted = await client.query(
      `INSERT INTO sales (company_id, sale_number, customer_id, warehouse_id, status, payment_status, subtotal, discount, grand_total, paid_amount, payment_method, notes, created_by)
       VALUES ($1, $2, $3, $4, 'COMPLETED', $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *`,
      [req.companyId, number, customerId, warehouseId, paymentStatus, subtotal, discount, grandTotal, paid, method, strOrNull(b.notes), req.user.id]
    );
    const saleRow = inserted.rows[0];

    for (const it of items) {
      const moved = await moveStock(client, {
        companyId: req.companyId, userId: req.user.id, productId: it.productId, warehouseId, delta: -it.quantity,
        type: 'OUTGOING', referenceType: 'SALE', referenceId: saleRow.id, reason: `Продажа ${number}`,
      });
      await client.query(
        `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, cost_price, total_amount) VALUES ($1, $2, $3, $4, $5, $6)`,
        [saleRow.id, it.productId, it.quantity, it.price, moved.previousAverageCost, it.total]
      );
    }
    if (grandTotal - paid > 0) await client.query(`UPDATE customers SET balance = balance + $1 WHERE id = $2`, [grandTotal - paid, customerId]);
    if (paid > 0) {
      const account = await resolveAccount(client, req.companyId, b.accountId, method);
      await postTransaction(client, {
        companyId: req.companyId, userId: req.user.id, account, type: 'INCOME', amount: paid, category: 'Оплата продажи',
        description: `Оплата продажи № ${number}`, paymentMethod: method, date: dateOrToday(null), referenceType: 'SALE', referenceId: saleRow.id,
      });
    }
    const full = await client.query(`${SALE_SELECT} WHERE s.id = $1`, [saleRow.id]);
    return saleDetails(client, full.rows[0]);
  });
  await notify(req.user.id, 'Новая продажа', `Продажа №${sale.sale_number} на сумму ${money(sale.totalAmount)} сум`, 'SALE', sale.id);
  res.status(201).json({ data: sale });
}));

api.post('/sales/:id/payments', h(async (req, res) => {
  const b = req.body || {};
  const amount = requirePositive(b.amount, 'Сумма оплаты');
  const sale = await tx(async (client) => {
    const found = await client.query(`SELECT * FROM sales WHERE id = $1 AND company_id = $2 FOR UPDATE`, [uuidOrNull(req.params.id), req.companyId]);
    const s = found.rows[0];
    if (!s) throw new HttpError(404, 'Продажа не найдена');
    const remaining = Math.round((num(s.grand_total) - num(s.paid_amount)) * 100) / 100;
    if (remaining <= 0) throw new HttpError(400, 'Продажа уже полностью оплачена');
    if (amount > remaining) throw new HttpError(400, `Сумма оплаты больше остатка: ${remaining}`);
    const method = methodOf({ paymentMethod: b.paymentMethod || b.method });
    const newPaid = num(s.paid_amount) + amount;
    await client.query(
      `UPDATE sales SET paid_amount = $1, payment_status = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3`,
      [newPaid, newPaid >= num(s.grand_total) ? 'PAID' : 'PARTIAL', s.id]
    );
    if (s.customer_id) await client.query(`UPDATE customers SET balance = balance - $1 WHERE id = $2`, [amount, s.customer_id]);
    const account = await resolveAccount(client, req.companyId, b.accountId, method);
    await postTransaction(client, {
      companyId: req.companyId, userId: req.user.id, account, type: 'INCOME', amount, category: 'Оплата продажи',
      description: `Оплата продажи № ${s.sale_number}`, paymentMethod: method, date: dateOrToday(b.date), referenceType: 'SALE', referenceId: s.id,
    });
    const full = await client.query(`${SALE_SELECT} WHERE s.id = $1`, [s.id]);
    return saleDetails(client, full.rows[0]);
  });
  res.status(201).json({ data: sale });
}));

// ============================================================================
// DEALS / CRM
// ============================================================================
const DEAL_STATUSES = ['lead', 'contact', 'negotiation', 'proposal', 'waiting_payment', 'won', 'lost'];
const DEAL_SELECT = `
  SELECT d.*, c.name AS customer_name, c.phone AS customer_phone,
         u.full_name AS assigned_employee_name, u.full_name AS assigned_to_name
  FROM deals d LEFT JOIN customers c ON d.customer_id = c.id LEFT JOIN users u ON d.assigned_to = u.id`;

function dealOut(row, comments) {
  const o = out(row);
  o.status = String(row.status || 'lead').toLowerCase();
  o.assignedEmployeeName = row.assigned_employee_name || null;
  if (comments) o.comments = comments.map((c) => ({ ...out(c), text: c.comment, content: c.comment, authorName: c.author_name }));
  return o;
}

async function dealComments(db, dealId) {
  const r = await db.query(
    `SELECT dc.*, u.full_name AS author_name, u.avatar_url AS author_avatar FROM deal_comments dc LEFT JOIN users u ON dc.user_id = u.id
     WHERE dc.deal_id = $1 ORDER BY dc.created_at ASC`,
    [dealId]
  );
  return r.rows;
}

async function companyMember(db, companyId, userId) {
  if (!isUuid(userId)) return null;
  const r = await db.query(`SELECT user_id FROM user_companies WHERE company_id = $1 AND user_id = $2`, [companyId, userId]);
  return r.rows[0] ? userId : null;
}

api.get('/deals', h(async (req, res) => {
  const conds = ['d.company_id = $1'];
  const vals = [req.companyId];
  const status = str(req.query.status).toLowerCase();
  if (status && status !== 'all') {
    vals.push(status);
    conds.push(`LOWER(d.status) = $${vals.length}`);
  }
  if (str(req.query.search)) {
    vals.push(`%${str(req.query.search)}%`);
    conds.push(`(d.title ILIKE $${vals.length} OR c.name ILIKE $${vals.length})`);
  }
  const result = await pool.query(`${DEAL_SELECT} WHERE ${conds.join(' AND ')} ORDER BY d.created_at DESC LIMIT 500`, vals);
  res.json({ data: result.rows.map((r) => dealOut(r)) });
}));

api.get('/deals/kanban', h(async (req, res) => {
  const result = await pool.query(`${DEAL_SELECT} WHERE d.company_id = $1 ORDER BY d.created_at DESC`, [req.companyId]);
  const columns = {};
  DEAL_STATUSES.forEach((s) => { columns[s] = []; });
  result.rows.forEach((r) => {
    const d = dealOut(r);
    (columns[d.status] || (columns[d.status] = [])).push(d);
  });
  res.json({ data: columns });
}));

api.post('/deals', h(async (req, res) => {
  const b = req.body || {};
  if (!str(b.title)) throw new HttpError(400, 'Укажите название сделки');
  const amount = num(b.amount != null ? b.amount : b.value);
  if (amount < 0) throw new HttpError(400, 'Сумма не может быть отрицательной');
  const status = DEAL_STATUSES.includes(str(b.status).toLowerCase()) ? str(b.status).toLowerCase() : 'lead';
  const deal = await tx(async (client) => {
    const customerId = await resolveCustomer(client, req.companyId, b);
    const assignedTo = await companyMember(client, req.companyId, b.assignedTo || b.assignedToId) || req.user.id;
    const inserted = await client.query(
      `INSERT INTO deals (company_id, title, customer_id, amount, status, description, expected_close_date, assigned_to, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
      [req.companyId, str(b.title), customerId, amount, status, str(b.description), b.expectedCloseDate ? dateOrToday(b.expectedCloseDate) : null, assignedTo, req.user.id]
    );
    return (await client.query(`${DEAL_SELECT} WHERE d.id = $1`, [inserted.rows[0].id])).rows[0];
  });
  await notify(req.user.id, 'Новая сделка', `Создана сделка: ${deal.title} на сумму ${money(deal.amount)} сум`, 'DEAL', deal.id);
  res.status(201).json({ data: dealOut(deal, []) });
}));

api.patch('/deals/:id/status', h(async (req, res) => {
  const status = str(req.body && req.body.status).toLowerCase();
  if (!DEAL_STATUSES.includes(status)) throw new HttpError(400, 'Неизвестный статус сделки');
  const updated = await pool.query(
    `UPDATE deals SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND company_id = $3 RETURNING id, title`,
    [status, uuidOrNull(req.params.id), req.companyId]
  );
  if (!updated.rows[0]) throw new HttpError(404, 'Сделка не найдена');
  const full = await pool.query(`${DEAL_SELECT} WHERE d.id = $1`, [updated.rows[0].id]);
  res.json({ data: dealOut(full.rows[0], await dealComments(pool, updated.rows[0].id)) });
}));

api.patch('/deals/:id', h(async (req, res) => {
  const b = req.body || {};
  const sets = [];
  const vals = [uuidOrNull(req.params.id), req.companyId];
  const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
  if (b.title !== undefined) {
    if (!str(b.title)) throw new HttpError(400, 'Укажите название сделки');
    set('title', str(b.title));
  }
  if (b.amount !== undefined) set('amount', Math.max(0, num(b.amount)));
  if (b.description !== undefined) set('description', str(b.description));
  if (b.expectedCloseDate !== undefined) set('expected_close_date', b.expectedCloseDate ? dateOrToday(b.expectedCloseDate) : null);
  if (b.status !== undefined && DEAL_STATUSES.includes(str(b.status).toLowerCase())) set('status', str(b.status).toLowerCase());
  if (sets.length === 0) throw new HttpError(400, 'Нет данных для обновления');
  const updated = await pool.query(`UPDATE deals SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND company_id = $2 RETURNING id`, vals);
  if (!updated.rows[0]) throw new HttpError(404, 'Сделка не найдена');
  const full = await pool.query(`${DEAL_SELECT} WHERE d.id = $1`, [updated.rows[0].id]);
  res.json({ data: dealOut(full.rows[0], await dealComments(pool, updated.rows[0].id)) });
}));

api.delete('/deals/:id', h(async (req, res) => {
  const result = await pool.query(`DELETE FROM deals WHERE id = $1 AND company_id = $2 RETURNING id`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Сделка не найдена');
  res.json({ success: true });
}));

api.post('/deals/:id/comments', h(async (req, res) => {
  const text = str(req.body && (req.body.text || req.body.content));
  if (!text) throw new HttpError(400, 'Введите текст комментария');
  const deal = await pool.query(`SELECT id FROM deals WHERE id = $1 AND company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!deal.rows[0]) throw new HttpError(404, 'Сделка не найдена');
  const inserted = await pool.query(`INSERT INTO deal_comments (deal_id, user_id, comment) VALUES ($1, $2, $3) RETURNING *`, [req.params.id, req.user.id, text]);
  res.status(201).json({ data: { ...out(inserted.rows[0]), text, content: text, authorName: req.user.fullName, author_name: req.user.fullName } });
}));

api.get('/deals/:id', h(async (req, res) => {
  const result = await pool.query(`${DEAL_SELECT} WHERE d.id = $1 AND d.company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Сделка не найдена');
  res.json({ data: dealOut(result.rows[0], await dealComments(pool, req.params.id)) });
}));

// ============================================================================
// TASKS
// ============================================================================
const TASK_STATUSES = ['todo', 'in_progress', 'review', 'done'];
const TASK_SELECT = `
  SELECT t.*, u.full_name AS assigned_to_name, u.avatar_url AS assigned_to_avatar, c.full_name AS created_by_name
  FROM tasks t LEFT JOIN users u ON t.assigned_to = u.id LEFT JOIN users c ON t.created_by = c.id`;

function taskOut(row, comments, attachments) {
  const o = out(row);
  o.status = String(row.status || 'todo').toLowerCase();
  o.priority = String(row.priority || 'medium').toLowerCase();
  o.deadline = row.due_date;
  o.assignedTo = row.assigned_to;
  if (comments) {
    o.comments = comments.map((c) => ({ ...out(c), content: c.comment, text: c.comment, authorName: c.author_name }));
  }
  if (attachments) {
    o.attachments = attachments.map((a) => fileUrl(a.file_url));
    o.attachmentFiles = attachments.map((a) => ({ id: a.id, name: a.file_name, url: fileUrl(a.file_url), size: num(a.file_size), createdAt: a.created_at }));
  }
  return o;
}

async function taskDetails(db, row) {
  const [comments, attachments] = await Promise.all([
    db.query(`SELECT tc.*, u.full_name AS author_name, u.avatar_url AS author_avatar FROM task_comments tc LEFT JOIN users u ON tc.user_id = u.id
              WHERE tc.task_id = $1 ORDER BY tc.created_at ASC`, [row.id]),
    db.query(`SELECT * FROM task_attachments WHERE task_id = $1 ORDER BY created_at ASC`, [row.id]),
  ]);
  return taskOut(row, comments.rows, attachments.rows);
}

api.get('/tasks', h(async (req, res) => {
  const conds = ['t.company_id = $1'];
  const vals = [req.companyId];
  const status = str(req.query.status).toLowerCase();
  if (status && status !== 'all') {
    vals.push(status);
    conds.push(`LOWER(t.status) = $${vals.length}`);
  }
  if (req.query.mine === 'true') {
    vals.push(req.user.id);
    conds.push(`t.assigned_to = $${vals.length}`);
  } else if (req.query.createdByMe === 'true') {
    vals.push(req.user.id);
    conds.push(`t.created_by = $${vals.length}`);
  } else if (isUuid(req.query.assignedTo)) {
    vals.push(req.query.assignedTo);
    conds.push(`t.assigned_to = $${vals.length}`);
  }
  if (str(req.query.search)) {
    vals.push(`%${str(req.query.search)}%`);
    conds.push(`(t.title ILIKE $${vals.length} OR t.description ILIKE $${vals.length})`);
  }
  const result = await pool.query(`${TASK_SELECT} WHERE ${conds.join(' AND ')} ORDER BY t.created_at DESC LIMIT 500`, vals);
  res.json({ data: result.rows.map((r) => taskOut(r)) });
}));

const handleCreateTask = h(async (req, res) => {
  const b = req.body || {};
  if (!str(b.title)) throw new HttpError(400, 'Укажите название задачи');
  let assignee = await companyMember(pool, req.companyId, b.assignedToId || b.assignedTo);
  if (!assignee && str(b.assignedToName)) {
    const found = await pool.query(
      `SELECT u.id FROM users u JOIN user_companies uc ON uc.user_id = u.id AND uc.company_id = $1
       WHERE u.is_active AND u.full_name ILIKE $2 ORDER BY (LOWER(u.full_name) = LOWER($3)) DESC LIMIT 1`,
      [req.companyId, `%${str(b.assignedToName)}%`, str(b.assignedToName)]
    );
    if (!found.rows[0]) throw new HttpError(400, `Сотрудник «${str(b.assignedToName)}» не найден в организации`);
    assignee = found.rows[0].id;
  }
  assignee = assignee || req.user.id;
  const priority = ['low', 'medium', 'high', 'urgent'].includes(str(b.priority).toLowerCase()) ? str(b.priority).toLowerCase() : 'medium';
  const deadline = b.deadline || b.dueDate;
  const inserted = await pool.query(
    `INSERT INTO tasks (company_id, title, description, assigned_to, created_by, priority, status, due_date, progress)
     VALUES ($1, $2, $3, $4, $5, $6, 'todo', $7, 0) RETURNING id`,
    [req.companyId, str(b.title), str(b.description), assignee, req.user.id, priority, deadline && !Number.isNaN(new Date(deadline).getTime()) ? new Date(deadline) : null]
  );
  const full = await pool.query(`${TASK_SELECT} WHERE t.id = $1`, [inserted.rows[0].id]);
  await notify(assignee, 'Новая задача', `Назначена задача: ${str(b.title)}`, 'TASK', inserted.rows[0].id);
  res.status(201).json({ data: taskOut(full.rows[0], [], []) });
});
api.post('/tasks', handleCreateTask);
api.post('/tasks/create', handleCreateTask);

const handleTaskStatus = h(async (req, res) => {
  const b = req.body || {};
  const status = str(b.status).toLowerCase();
  if (!TASK_STATUSES.includes(status)) throw new HttpError(400, 'Неизвестный статус задачи');
  let progress = b.progress != null ? Math.round(num(b.progress)) : null;
  if (progress != null) progress = Math.min(100, Math.max(0, progress));
  if (status === 'done') progress = 100;
  const updated = await pool.query(
    `UPDATE tasks SET status = $1, progress = COALESCE($2, progress), updated_at = CURRENT_TIMESTAMP
     WHERE id = $3 AND company_id = $4 RETURNING id, title, assigned_to, created_by`,
    [status, progress, uuidOrNull(req.params.id), req.companyId]
  );
  const t = updated.rows[0];
  if (!t) throw new HttpError(404, 'Задание не найдено');
  const target = t.created_by && t.created_by !== req.user.id ? t.created_by : t.assigned_to;
  if (target && target !== req.user.id) await notify(target, 'Статус задачи обновлен', `Задача "${t.title}" переведена в "${status}"`, 'TASK', t.id);
  const full = await pool.query(`${TASK_SELECT} WHERE t.id = $1`, [t.id]);
  res.json({ data: await taskDetails(pool, full.rows[0]) });
});
api.put('/tasks/:id/status', handleTaskStatus);
api.patch('/tasks/:id/status', handleTaskStatus);

api.patch('/tasks/:id', h(async (req, res) => {
  const b = req.body || {};
  const sets = [];
  const vals = [uuidOrNull(req.params.id), req.companyId];
  const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
  if (b.title !== undefined) {
    if (!str(b.title)) throw new HttpError(400, 'Укажите название задачи');
    set('title', str(b.title));
  }
  if (b.description !== undefined) set('description', str(b.description));
  if (b.priority !== undefined && ['low', 'medium', 'high', 'urgent'].includes(str(b.priority).toLowerCase())) set('priority', str(b.priority).toLowerCase());
  if (b.deadline !== undefined) set('due_date', b.deadline && !Number.isNaN(new Date(b.deadline).getTime()) ? new Date(b.deadline) : null);
  if (b.progress !== undefined) set('progress', Math.min(100, Math.max(0, Math.round(num(b.progress)))));
  if (b.assignedToId !== undefined) {
    const assignee = await companyMember(pool, req.companyId, b.assignedToId);
    if (!assignee) throw new HttpError(400, 'Сотрудник не найден в организации');
    set('assigned_to', assignee);
  }
  if (sets.length === 0) throw new HttpError(400, 'Нет данных для обновления');
  const updated = await pool.query(`UPDATE tasks SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND company_id = $2 RETURNING id`, vals);
  if (!updated.rows[0]) throw new HttpError(404, 'Задание не найдено');
  const full = await pool.query(`${TASK_SELECT} WHERE t.id = $1`, [updated.rows[0].id]);
  res.json({ data: await taskDetails(pool, full.rows[0]) });
}));

api.delete('/tasks/:id', h(async (req, res) => {
  const files = await pool.query(
    `SELECT ta.file_url FROM task_attachments ta JOIN tasks t ON t.id = ta.task_id WHERE t.id = $1 AND t.company_id = $2`,
    [uuidOrNull(req.params.id), req.companyId]
  );
  const result = await pool.query(`DELETE FROM tasks WHERE id = $1 AND company_id = $2 RETURNING id`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Задание не найдено');
  files.rows.forEach((f) => removeUploadedFile(f.file_url));
  res.json({ success: true });
}));

api.post('/tasks/:id/comments', h(async (req, res) => {
  const content = str(req.body && (req.body.content || req.body.text));
  if (!content) throw new HttpError(400, 'Введите текст комментария');
  const task = await pool.query(`SELECT id, title, assigned_to, created_by FROM tasks WHERE id = $1 AND company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!task.rows[0]) throw new HttpError(404, 'Задание не найдено');
  const inserted = await pool.query(`INSERT INTO task_comments (task_id, user_id, comment) VALUES ($1, $2, $3) RETURNING *`, [req.params.id, req.user.id, content]);
  for (const target of new Set([task.rows[0].assigned_to, task.rows[0].created_by])) {
    if (target && target !== req.user.id) await notify(target, 'Новый комментарий', `${req.user.fullName}: ${content.slice(0, 120)}`, 'TASK', task.rows[0].id);
  }
  res.status(201).json({ data: { ...out(inserted.rows[0]), content, text: content, authorName: req.user.fullName, author_name: req.user.fullName } });
}));

api.post('/tasks/:id/attachments', upload.single('file'), h(async (req, res) => {
  if (!req.file) throw new HttpError(400, 'Файл не прикреплен');
  const task = await pool.query(`SELECT id FROM tasks WHERE id = $1 AND company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!task.rows[0]) {
    removeUploadedFile(req.file.filename);
    throw new HttpError(404, 'Задание не найдено');
  }
  const url = `/uploads/${req.file.filename}`;
  const inserted = await pool.query(
    `INSERT INTO task_attachments (task_id, file_name, file_url, file_size, mime_type, uploaded_by) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [req.params.id, originalName(req.file), url, req.file.size, req.file.mimetype, req.user.id]
  );
  res.status(201).json({ id: inserted.rows[0].id, url: fileUrl(url), fileName: originalName(req.file), size: req.file.size });
}));

api.delete('/tasks/:id/attachments', h(async (req, res) => {
  const target = str(req.query.url || req.query.id || (req.body && (req.body.url || req.body.id)));
  if (!target) throw new HttpError(400, 'Не указан файл');
  const name = path.basename(target.split('?')[0]);
  const removed = await pool.query(
    `DELETE FROM task_attachments ta USING tasks t
     WHERE ta.task_id = t.id AND t.id = $1 AND t.company_id = $2 AND (ta.id::text = $3 OR ta.file_url LIKE $4) RETURNING ta.file_url`,
    [uuidOrNull(req.params.id), req.companyId, target, `%/${name}`]
  );
  if (!removed.rows[0]) throw new HttpError(404, 'Файл не найден');
  removed.rows.forEach((r) => removeUploadedFile(r.file_url));
  res.json({ success: true });
}));

api.get('/tasks/:id', h(async (req, res) => {
  const result = await pool.query(`${TASK_SELECT} WHERE t.id = $1 AND t.company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Задание не найдено');
  res.json({ data: await taskDetails(pool, result.rows[0]) });
}));

// ============================================================================
// MESSENGER
// ============================================================================
async function ensureDefaultRoom(companyId, userId) {
  const existing = await pool.query(`SELECT 1 FROM chat_rooms WHERE company_id = $1 LIMIT 1`, [companyId]);
  if (existing.rows[0]) return;
  await pool.query(`INSERT INTO chat_rooms (name, is_group, created_by, company_id) VALUES ('Общий чат', TRUE, $1, $2)`, [userId, companyId]);
}

// Messages the viewer must not see: from users they blocked, or ones they reported.
// `viewer` is the SQL placeholder holding the viewer's user id; the outer query aliases messages as m.
const HIDDEN_FOR = (viewer) =>
  `NOT EXISTS (SELECT 1 FROM user_blocks ub WHERE ub.blocker_id = ${viewer} AND ub.blocked_id = m.sender_id)
   AND NOT EXISTS (SELECT 1 FROM message_reports mr WHERE mr.reporter_id = ${viewer} AND mr.message_id = m.id)`;

async function roomOfCompany(roomId, companyId) {
  const r = await pool.query(`SELECT id FROM chat_rooms WHERE id = $1 AND company_id = $2`, [uuidOrNull(roomId), companyId]);
  if (!r.rows[0]) throw new HttpError(404, 'Чат не найден');
  return r.rows[0].id;
}

api.get('/chat/rooms', h(async (req, res) => {
  await ensureDefaultRoom(req.companyId, req.user.id);
  const result = await pool.query(
    `SELECT r.*, r.name AS title,
            lm.content AS last_message, COALESCE(lm.created_at, r.created_at) AS last_message_time,
            (SELECT count(*)::int FROM messages m WHERE m.room_id = r.id AND m.sender_id <> $2 AND ${HIDDEN_FOR('$2')}
               AND m.created_at > COALESCE((SELECT last_read_at FROM chat_members cm WHERE cm.room_id = r.id AND cm.user_id = $2), 'epoch')) AS unread_count
     FROM chat_rooms r
     LEFT JOIN LATERAL (SELECT content, created_at FROM messages m WHERE m.room_id = r.id AND ${HIDDEN_FOR('$2')} ORDER BY created_at DESC LIMIT 1) lm ON TRUE
     WHERE r.company_id = $1
     ORDER BY last_message_time DESC`,
    [req.companyId, req.user.id]
  );
  res.json({ data: out(result.rows) });
}));

api.post('/chat/rooms', h(async (req, res) => {
  const name = str(req.body && (req.body.name || req.body.title));
  if (!name) throw new HttpError(400, 'Укажите название чата');
  const result = await pool.query(
    `INSERT INTO chat_rooms (name, is_group, created_by, company_id) VALUES ($1, TRUE, $2, $3) RETURNING *, name AS title`,
    [name, req.user.id, req.companyId]
  );
  res.status(201).json({ data: out(result.rows[0]) });
}));

api.get('/chat/rooms/:roomId/messages', h(async (req, res) => {
  const roomId = await roomOfCompany(req.params.roomId, req.companyId);
  const result = await pool.query(
    `SELECT m.*, u.full_name AS sender_name, u.avatar_url AS sender_avatar, (m.sender_id = $2) AS is_mine
     FROM (SELECT * FROM messages m WHERE m.room_id = $1 AND ${HIDDEN_FOR('$2')} ORDER BY created_at DESC LIMIT 300) m
     LEFT JOIN users u ON m.sender_id = u.id ORDER BY m.created_at ASC`,
    [roomId, req.user.id]
  );
  res.json({ data: result.rows.map((m) => ({ ...out(m), attachment_url: fileUrl(m.attachment_url), attachmentUrl: fileUrl(m.attachment_url) })) });
}));

api.post('/chat/rooms/:roomId/messages', h(async (req, res) => {
  const b = req.body || {};
  const roomId = await roomOfCompany(req.params.roomId, req.companyId);
  const content = str(b.content || b.text);
  const attachment = relativeUploadPath(b.attachmentUrl);
  if (!content && !attachment) throw new HttpError(400, 'Сообщение пустое');
  const inserted = await pool.query(
    `INSERT INTO messages (room_id, sender_id, content, attachment_url, attachment_type, reply_to_content) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [roomId, req.user.id, content, attachment, strOrNull(b.attachmentType), strOrNull(b.replyToContent)]
  );
  const profile = await pool.query(`SELECT full_name, avatar_url FROM users WHERE id = $1`, [req.user.id]);
  const msg = out({ ...inserted.rows[0], sender_name: profile.rows[0].full_name, sender_avatar: profile.rows[0].avatar_url });
  msg.attachment_url = fileUrl(inserted.rows[0].attachment_url);
  msg.attachmentUrl = msg.attachment_url;
  io.to(`room:${roomId}`).emit('newMessage', msg);
  res.status(201).json({ data: { ...msg, is_mine: true, isMine: true } });
}));

api.post('/chat/rooms/:roomId/read', h(async (req, res) => {
  const roomId = await roomOfCompany(req.params.roomId, req.companyId);
  await pool.query(
    `INSERT INTO chat_members (room_id, user_id, last_read_at) VALUES ($1, $2, CURRENT_TIMESTAMP)
     ON CONFLICT (room_id, user_id) DO UPDATE SET last_read_at = CURRENT_TIMESTAMP`,
    [roomId, req.user.id]
  );
  res.json({ success: true });
}));

// Report a message. It disappears for the reporter at once; the organization's
// owners and admins are notified, and the report is stored for the Opero team to review.
api.post('/chat/messages/:messageId/report', h(async (req, res) => {
  const found = await pool.query(
    `SELECT m.id, m.content, m.sender_id, u.full_name AS sender_name
     FROM messages m JOIN chat_rooms r ON r.id = m.room_id LEFT JOIN users u ON u.id = m.sender_id
     WHERE m.id = $1 AND r.company_id = $2`,
    [uuidOrNull(req.params.messageId), req.companyId]
  );
  const msg = found.rows[0];
  if (!msg) throw new HttpError(404, 'Сообщение не найдено');
  if (msg.sender_id === req.user.id) throw new HttpError(400, 'Нельзя пожаловаться на своё сообщение');
  const reason = str(req.body && req.body.reason) || 'Неприемлемое содержание';
  const inserted = await pool.query(
    `INSERT INTO message_reports (message_id, company_id, reporter_id, sender_id, message_content, reason)
     VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (message_id, reporter_id) DO NOTHING RETURNING id`,
    [msg.id, req.companyId, req.user.id, msg.sender_id, msg.content, reason]
  );
  if (inserted.rows[0]) {
    console.log(`Message report ${inserted.rows[0].id}: message ${msg.id} by user ${msg.sender_id}, reason: ${reason}`);
    const admins = await pool.query(
      `SELECT user_id FROM user_companies WHERE company_id = $1 AND role IN ('OWNER', 'ADMIN') AND user_id NOT IN ($2, $3)`,
      [req.companyId, req.user.id, msg.sender_id]
    );
    for (const a of admins.rows) {
      await notify(a.user_id, 'Жалоба на сообщение', `Пожаловались на сообщение ${msg.sender_name || 'сотрудника'}: ${reason}`, 'SYSTEM', msg.id);
    }
  }
  res.status(201).json({ success: true, message: 'Жалоба отправлена' });
}));

api.get('/chat/blocks', h(async (req, res) => {
  const result = await pool.query(
    `SELECT u.id, u.full_name, b.created_at FROM user_blocks b JOIN users u ON u.id = b.blocked_id
     WHERE b.blocker_id = $1 ORDER BY b.created_at DESC`,
    [req.user.id]
  );
  res.json({ data: out(result.rows) });
}));

api.post('/chat/blocks', h(async (req, res) => {
  const userId = uuidOrNull(req.body && req.body.userId);
  if (!userId) throw new HttpError(400, 'Не указан пользователь');
  if (userId === req.user.id) throw new HttpError(400, 'Нельзя заблокировать себя');
  const exists = await pool.query(`SELECT 1 FROM users WHERE id = $1`, [userId]);
  if (!exists.rows[0]) throw new HttpError(404, 'Пользователь не найден');
  await pool.query(`INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [req.user.id, userId]);
  res.status(201).json({ success: true });
}));

api.delete('/chat/blocks/:userId', h(async (req, res) => {
  await pool.query(`DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`, [req.user.id, uuidOrNull(req.params.userId)]);
  res.json({ success: true });
}));

io.use((socket, next) => {
  try {
    const token = (socket.handshake.auth && socket.handshake.auth.token) || String(socket.handshake.headers.authorization || '').replace('Bearer ', '');
    socket.data.userId = jwt.verify(token, JWT_SECRET).sub;
    next();
  } catch (e) {
    next(new Error('unauthorized'));
  }
});

io.on('connection', (socket) => {
  socket.on('joinRoom', async (roomId) => {
    const allowed = await pool.query(
      `SELECT 1 FROM chat_rooms r JOIN user_companies uc ON uc.company_id = r.company_id AND uc.user_id = $2 WHERE r.id = $1`,
      [uuidOrNull(roomId), socket.data.userId]
    ).catch(() => ({ rows: [] }));
    if (allowed.rows[0]) socket.join(`room:${roomId}`);
  });
});

// ============================================================================
// EMPLOYEES & DEPARTMENTS
// ============================================================================
const EMPLOYEE_SELECT = `
  SELECT u.id, u.email, u.full_name, u.phone, u.position, u.avatar_url, u.is_active, u.created_at, u.updated_at,
         u.department_id, d.name AS department_name,
         CASE WHEN uc.role = 'OWNER' THEN 'SUPER_ADMIN' ELSE uc.role END AS role,
         (SELECT count(*)::int FROM tasks t WHERE t.assigned_to = u.id AND t.company_id = uc.company_id AND LOWER(t.status) <> 'done') AS active_tasks_count
  FROM users u
  JOIN user_companies uc ON uc.user_id = u.id
  LEFT JOIN departments d ON u.department_id = d.id AND d.company_id = uc.company_id`;

async function resolveDepartment(db, companyId, body) {
  if (isUuid(body.departmentId)) {
    const d = await db.query(`SELECT id FROM departments WHERE id = $1 AND company_id = $2`, [body.departmentId, companyId]);
    if (d.rows[0]) return d.rows[0].id;
  }
  const name = str(body.departmentName || body.department);
  if (!name) return undefined;
  const existing = await db.query(`SELECT id FROM departments WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [companyId, name]);
  if (existing.rows[0]) return existing.rows[0].id;
  return (await db.query(`INSERT INTO departments (name, company_id) VALUES ($1, $2) RETURNING id`, [name, companyId])).rows[0].id;
}

const normalizeRole = (r) => (ROLE_IDS.includes(str(r).toUpperCase()) ? str(r).toUpperCase() : 'EMPLOYEE');

api.get('/employees', h(async (req, res) => {
  const q = req.query;
  const conds = ['uc.company_id = $1', 'u.is_active'];
  const vals = [req.companyId];
  if (str(q.search)) {
    vals.push(`%${str(q.search)}%`);
    conds.push(`(u.full_name ILIKE $${vals.length} OR u.email ILIKE $${vals.length} OR u.phone ILIKE $${vals.length})`);
  }
  const role = str(q.role).toUpperCase();
  if (role && role !== 'ALL') {
    vals.push(role === 'SUPER_ADMIN' ? 'OWNER' : role);
    vals.push(role);
    conds.push(`uc.role IN ($${vals.length - 1}, $${vals.length})`);
  }
  if (isUuid(q.departmentId)) {
    vals.push(q.departmentId);
    conds.push(`u.department_id = $${vals.length}`);
  }
  const result = await pool.query(`${EMPLOYEE_SELECT} WHERE ${conds.join(' AND ')} ORDER BY u.created_at ASC`, vals);
  res.json({ data: out(result.rows) });
}));

const listDepartments = h(async (req, res) => {
  const result = await pool.query(
    `SELECT d.*, (SELECT count(*)::int FROM users u JOIN user_companies uc ON uc.user_id = u.id AND uc.company_id = d.company_id
                  WHERE u.department_id = d.id AND u.is_active) AS employees_count
     FROM departments d WHERE d.company_id = $1 ORDER BY d.name ASC`,
    [req.companyId]
  );
  res.json({ data: out(result.rows) });
});
api.get('/employees/departments', listDepartments);
api.get('/departments', listDepartments);

api.post('/departments', requireAdmin, h(async (req, res) => {
  if (!str(req.body && req.body.name)) throw new HttpError(400, 'Укажите название отдела');
  const id = await resolveDepartment(pool, req.companyId, { departmentName: req.body.name });
  const result = await pool.query(`SELECT * FROM departments WHERE id = $1`, [id]);
  res.status(201).json({ data: out(result.rows[0]) });
}));

api.get('/roles', (req, res) => {
  res.json({
    data: [
      { id: 'SUPER_ADMIN', name: 'Главный администратор', description: 'Владелец / Руководитель. Полный доступ ко всем модулям, финансам и назначению ролей.', level: 1 },
      { id: 'ADMIN', name: 'Администратор', description: 'Операционное управление. Управление персоналом, складом, закупками, сделками и задачами.', level: 2 },
      { id: 'MANAGER', name: 'Менеджер проектов / CRM', description: 'Управление клиентами, воронка сделок, постановка и контроль задач сотрудникам.', level: 3 },
      { id: 'ACCOUNTANT', name: 'Бухгалтер / Финансист', description: 'Финансовый учет, кассы, доходы, расходы, выплаты и расчет зарплат.', level: 3 },
      { id: 'WAREHOUSE_KEEPER', name: 'Кладовщик / Склад', description: 'Приемка поставок, контроль остатков товаров, списания и инвентаризация.', level: 4 },
      { id: 'EMPLOYEE', name: 'Сотрудник / Специалист', description: 'Выполнение назначенных задач, корпоративный мессенджер и файлы.', level: 5 },
    ],
  });
});

api.post('/employees', requireAdmin, h(async (req, res) => {
  const b = req.body || {};
  const email = str(b.email).toLowerCase();
  const fullName = str(b.fullName || b.name);
  if (!fullName) throw new HttpError(400, 'Укажите ФИО сотрудника');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'Укажите корректный адрес электронной почты');
  const role = normalizeRole(b.role);
  if (role === 'SUPER_ADMIN' && req.companyRole !== 'OWNER') throw new HttpError(403, 'Назначить главного администратора может только владелец');

  const givenPassword = typeof b.password === 'string' ? b.password : '';
  if (givenPassword && givenPassword.length < 6) throw new HttpError(400, 'Пароль должен содержать не менее 6 символов');

  const result = await tx(async (client) => {
    const departmentId = await resolveDepartment(client, req.companyId, b);
    const existing = await client.query(`SELECT * FROM users WHERE LOWER(email) = $1`, [email]);
    let user = existing.rows[0];
    let temporaryPassword = null;
    if (user) {
      const member = await client.query(`SELECT 1 FROM user_companies WHERE user_id = $1 AND company_id = $2`, [user.id, req.companyId]);
      if (member.rows[0]) throw new HttpError(400, 'Сотрудник с таким Email уже есть в организации');
    } else {
      temporaryPassword = givenPassword || crypto.randomBytes(6).toString('base64url');
      const inserted = await client.query(
        `INSERT INTO users (full_name, email, phone, role, position, department_id, password_hash, is_active, current_company_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, $8) RETURNING *`,
        [fullName, email, strOrNull(b.phone), role, str(b.position) || 'Сотрудник', departmentId || null, await bcrypt.hash(temporaryPassword, 10), req.companyId]
      );
      user = inserted.rows[0];
    }
    await client.query(
      `INSERT INTO user_companies (user_id, company_id, role, is_default)
       VALUES ($1, $2, $3, NOT EXISTS (SELECT 1 FROM user_companies WHERE user_id = $1))`,
      [user.id, req.companyId, role]
    );
    const row = await client.query(`${EMPLOYEE_SELECT} WHERE u.id = $1 AND uc.company_id = $2`, [user.id, req.companyId]);
    return { row: row.rows[0], temporaryPassword: givenPassword ? null : temporaryPassword, existingUser: temporaryPassword === null };
  });
  await notify(result.row.id, 'Добро пожаловать', 'Вас добавили в организацию', 'SYSTEM', req.companyId);
  // The generated password is shown once so the administrator can hand it to the employee.
  // An already-registered person keeps their own password; existingUser tells the app so.
  res.status(201).json({ data: out(result.row), temporaryPassword: result.temporaryPassword, existingUser: result.existingUser });
}));

async function employeeInCompany(db, companyId, id) {
  const r = await db.query(`${EMPLOYEE_SELECT} WHERE u.id = $1 AND uc.company_id = $2`, [uuidOrNull(id), companyId]);
  return r.rows[0] || null;
}

api.get('/employees/:id', h(async (req, res) => {
  const emp = await employeeInCompany(pool, req.companyId, req.params.id);
  if (!emp) throw new HttpError(404, 'Сотрудник не найден');
  const tasks = await pool.query(
    `SELECT id, title, status, updated_at FROM tasks WHERE company_id = $1 AND assigned_to = $2 ORDER BY updated_at DESC LIMIT 10`,
    [req.companyId, emp.id]
  );
  res.json({ data: { ...out(emp), recentActivity: tasks.rows.map((t) => ({ id: t.id, title: t.title, status: String(t.status).toLowerCase(), date: t.updated_at })) } });
}));

async function changeEmployeeRole(db, req, targetId, role) {
  const target = await db.query(`SELECT role FROM user_companies WHERE user_id = $1 AND company_id = $2 FOR UPDATE`, [targetId, req.companyId]);
  if (!target.rows[0]) throw new HttpError(404, 'Сотрудник не найден');
  if (target.rows[0].role === 'OWNER') throw new HttpError(403, 'Роль владельца организации изменить нельзя');
  if (role === 'SUPER_ADMIN' && req.companyRole !== 'OWNER') throw new HttpError(403, 'Назначить главного администратора может только владелец');
  await db.query(`UPDATE user_companies SET role = $1 WHERE user_id = $2 AND company_id = $3`, [role, targetId, req.companyId]);
}

api.patch('/employees/:id/role', requireAdmin, h(async (req, res) => {
  if (!str(req.body && req.body.role)) throw new HttpError(400, 'Роль не указана');
  const role = normalizeRole(req.body.role);
  await tx((client) => changeEmployeeRole(client, req, uuidOrNull(req.params.id), role));
  await notify(req.params.id, 'Изменение роли в системе', `Вам назначена роль: ${role}`, 'SYSTEM', req.params.id);
  res.json({ data: out(await employeeInCompany(pool, req.companyId, req.params.id)), message: 'Роль успешно изменена' });
}));

// Administrators reset a forgotten password; the new one is shown to them once.
api.post('/employees/:id/reset-password', requireAdmin, h(async (req, res) => {
  const id = uuidOrNull(req.params.id);
  const target = await pool.query(`SELECT role FROM user_companies WHERE user_id = $1 AND company_id = $2`, [id, req.companyId]);
  if (!target.rows[0]) throw new HttpError(404, 'Сотрудник не найден');
  if (target.rows[0].role === 'OWNER' && id !== req.user.id) throw new HttpError(403, 'Пароль владельца организации сбросить нельзя');
  const temporaryPassword = crypto.randomBytes(6).toString('base64url');
  await pool.query(
    `UPDATE users SET password_hash = $1, token_version = token_version + 1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
    [await bcrypt.hash(temporaryPassword, 10), id]
  );
  await notify(id, 'Пароль сброшен', 'Администратор сбросил ваш пароль. Смените его в настройках после входа', 'SYSTEM', id);
  res.json({ success: true, temporaryPassword });
}));

const handleUpdateEmployee = h(async (req, res) => {
  const b = req.body || {};
  const id = uuidOrNull(req.params.id);
  if (id !== req.user.id && !ADMIN_ROLES.has(req.companyRole)) throw new HttpError(403, 'Недостаточно прав для этого действия');
  await tx(async (client) => {
    if (!(await employeeInCompany(client, req.companyId, id))) throw new HttpError(404, 'Сотрудник не найден');
    const sets = [];
    const vals = [id];
    const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
    const newName = b.fullName !== undefined ? b.fullName : b.name;
    if (newName !== undefined) {
      if (!str(newName)) throw new HttpError(400, 'Укажите ФИО сотрудника');
      set('full_name', str(newName));
    }
    if (b.phone !== undefined) set('phone', strOrNull(b.phone));
    if (b.position !== undefined) set('position', strOrNull(b.position));
    const departmentId = await resolveDepartment(client, req.companyId, b);
    if (departmentId !== undefined) set('department_id', departmentId);
    if (sets.length > 0) await client.query(`UPDATE users SET ${sets.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, vals);
    if (b.role !== undefined && ADMIN_ROLES.has(req.companyRole) && id !== req.user.id) await changeEmployeeRole(client, req, id, normalizeRole(b.role));
    if (sets.length === 0 && b.role === undefined) throw new HttpError(400, 'Нет данных для обновления');
  });
  res.json({ data: out(await employeeInCompany(pool, req.companyId, id)), message: 'Данные сотрудника обновлены' });
});
api.patch('/employees/:id', handleUpdateEmployee);
api.put('/employees/:id', handleUpdateEmployee);

api.delete('/employees/:id', requireAdmin, h(async (req, res) => {
  const id = uuidOrNull(req.params.id);
  if (id === req.user.id) throw new HttpError(400, 'Нельзя удалить самого себя');
  await tx(async (client) => {
    const target = await client.query(`SELECT role FROM user_companies WHERE user_id = $1 AND company_id = $2`, [id, req.companyId]);
    if (!target.rows[0]) throw new HttpError(404, 'Сотрудник не найден');
    if (target.rows[0].role === 'OWNER') throw new HttpError(403, 'Владельца организации удалить нельзя');
    await client.query(`DELETE FROM user_companies WHERE user_id = $1 AND company_id = $2`, [id, req.companyId]);
    const left = await client.query(`SELECT count(*)::int AS n FROM user_companies WHERE user_id = $1`, [id]);
    // An employee who belongs to no other organization can no longer sign in.
    if (left.rows[0].n === 0) {
      await client.query(`UPDATE users SET is_active = FALSE, token_version = token_version + 1, current_company_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [id]);
    } else {
      await client.query(`UPDATE users SET current_company_id = NULL WHERE id = $1 AND current_company_id = $2`, [id, req.companyId]);
    }
  });
  res.json({ success: true, message: 'Сотрудник удалён из организации' });
}));

// ============================================================================
// CUSTOMERS & SUPPLIERS
// ============================================================================
function partyRoutes(base, table, label, historySql, historyKey) {
  api.get(`/${base}`, h(async (req, res) => {
    const vals = [req.companyId];
    let where = 'x.company_id = $1';
    if (str(req.query.search)) {
      vals.push(`%${str(req.query.search)}%`);
      where += ` AND (x.name ILIKE $2 OR x.phone ILIKE $2 OR x.email ILIKE $2)`;
    }
    const totalSql = table === 'customers'
      ? `(SELECT COALESCE(SUM(grand_total), 0) FROM sales s WHERE s.customer_id = x.id AND s.status <> 'CANCELLED')`
      : `(SELECT COALESCE(SUM(total_amount + additional_costs), 0) FROM incoming_shipments s WHERE s.supplier_id = x.id AND s.status = 'RECEIVED')`;
    const result = await pool.query(`SELECT x.*, ${totalSql} AS total_purchases FROM ${table} x WHERE ${where} ORDER BY x.created_at DESC LIMIT 500`, vals);
    res.json({ data: result.rows.map((r) => ({ ...out(r), debt: num(r.balance), debtAmount: num(r.balance), payableBalance: num(r.balance), totalSales: num(r.total_purchases) })) });
  }));

  api.post(`/${base}`, h(async (req, res) => {
    const b = req.body || {};
    if (!str(b.name)) throw new HttpError(400, `Укажите название: ${label}`);
    const dup = await pool.query(`SELECT 1 FROM ${table} WHERE company_id = $1 AND LOWER(name) = LOWER($2)`, [req.companyId, str(b.name)]);
    if (dup.rows[0]) throw new HttpError(400, `${label} с таким названием уже существует`);
    const cols = ['company_id', 'name', 'phone', 'email', 'address', 'inn'];
    const vals = [req.companyId, str(b.name), str(b.phone), str(b.email), str(b.address), strOrNull(b.inn)];
    if (table === 'suppliers') {
      cols.push('contact_person');
      vals.push(str(b.contactPerson || b.contact));
    } else {
      cols.push('notes');
      vals.push(strOrNull(b.notes));
    }
    const result = await pool.query(`INSERT INTO ${table} (${cols.join(', ')}) VALUES (${cols.map((_, i) => `$${i + 1}`).join(', ')}) RETURNING *`, vals);
    res.status(201).json({ data: out(result.rows[0]) });
  }));

  api.get(`/${base}/:id`, h(async (req, res) => {
    const result = await pool.query(`SELECT * FROM ${table} WHERE id = $1 AND company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
    if (!result.rows[0]) throw new HttpError(404, `${label} не найден`);
    const history = await pool.query(historySql, [req.params.id]);
    const total = history.rows.reduce((s, r) => s + num(r.amount), 0);
    res.json({
      data: {
        ...out(result.rows[0]), [historyKey]: out(history.rows), purchaseHistory: out(history.rows), purchases: out(history.rows),
        totalPurchases: total, totalSales: total, debt: num(result.rows[0].balance), debtAmount: num(result.rows[0].balance), payableBalance: num(result.rows[0].balance),
      },
    });
  }));

  api.patch(`/${base}/:id`, h(async (req, res) => {
    const b = req.body || {};
    const sets = [];
    const vals = [uuidOrNull(req.params.id), req.companyId];
    const set = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };
    if (b.name !== undefined) {
      if (!str(b.name)) throw new HttpError(400, `Укажите название: ${label}`);
      set('name', str(b.name));
    }
    ['phone', 'email', 'address'].forEach((k) => { if (b[k] !== undefined) set(k, str(b[k])); });
    if (b.inn !== undefined) set('inn', strOrNull(b.inn));
    if (table === 'suppliers' && (b.contactPerson !== undefined || b.contact !== undefined)) set('contact_person', str(b.contactPerson || b.contact));
    if (table === 'customers' && b.notes !== undefined) set('notes', strOrNull(b.notes));
    if (sets.length === 0) throw new HttpError(400, 'Нет данных для обновления');
    const result = await pool.query(`UPDATE ${table} SET ${sets.join(', ')} WHERE id = $1 AND company_id = $2 RETURNING *`, vals);
    if (!result.rows[0]) throw new HttpError(404, `${label} не найден`);
    res.json({ data: out(result.rows[0]) });
  }));

  api.delete(`/${base}/:id`, h(async (req, res) => {
    const found = await pool.query(`SELECT balance FROM ${table} WHERE id = $1 AND company_id = $2`, [uuidOrNull(req.params.id), req.companyId]);
    if (!found.rows[0]) throw new HttpError(404, `${label} не найден`);
    if (num(found.rows[0].balance) !== 0) throw new HttpError(400, 'Нельзя удалить: есть непогашенная задолженность');
    await pool.query(`DELETE FROM ${table} WHERE id = $1 AND company_id = $2`, [req.params.id, req.companyId]);
    res.json({ success: true });
  }));
}

partyRoutes('customers', 'customers', 'Клиент',
  `SELECT id, sale_number, grand_total AS amount, grand_total AS total_amount, paid_amount, LOWER(payment_status) AS status, created_at, created_at AS date
   FROM sales WHERE customer_id = $1 ORDER BY created_at DESC LIMIT 50`, 'sales');
partyRoutes('suppliers', 'suppliers', 'Поставщик',
  `SELECT id, shipment_number, shipment_number AS invoice_number, total_amount AS amount, total_amount, total_amount AS total_cost, LOWER(status) AS status, created_at, created_at AS date
   FROM incoming_shipments WHERE supplier_id = $1 ORDER BY created_at DESC LIMIT 50`, 'shipments');

// ============================================================================
// DOCUMENTS & FOLDERS
// ============================================================================
function documentOut(row) {
  const o = out(row);
  o.url = fileUrl(row.file_path);
  o.file_path = o.url;
  o.extension = row.file_type;
  o.ext = row.file_type;
  o.sizeBytes = num(row.file_size);
  o.size = o.sizeBytes;
  o.updated_at = row.created_at;
  return o;
}

api.get('/documents/folders', h(async (req, res) => {
  const result = await pool.query(
    `SELECT f.*, (SELECT count(*)::int FROM documents d WHERE d.folder_id = f.id) AS files_count
     FROM document_folders f WHERE f.company_id = $1 ORDER BY f.created_at ASC`,
    [req.companyId]
  );
  res.json({ data: out(result.rows) });
}));

api.post('/documents/folders', h(async (req, res) => {
  const name = str(req.body && req.body.name);
  if (!name) throw new HttpError(400, 'Укажите название папки');
  const result = await pool.query(`INSERT INTO document_folders (name, company_id) VALUES ($1, $2) RETURNING *, 0 AS files_count`, [name, req.companyId]);
  res.status(201).json({ data: out(result.rows[0]) });
}));

api.patch('/documents/folders/:id', h(async (req, res) => {
  const name = str(req.body && req.body.name);
  if (!name) throw new HttpError(400, 'Укажите название папки');
  const result = await pool.query(`UPDATE document_folders SET name = $1 WHERE id = $2 AND company_id = $3 RETURNING *`, [name, uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Папка не найдена');
  res.json({ data: out(result.rows[0]) });
}));

api.delete('/documents/folders/:id', h(async (req, res) => {
  const id = uuidOrNull(req.params.id);
  const files = await tx(async (client) => {
    const folder = await client.query(`SELECT id FROM document_folders WHERE id = $1 AND company_id = $2`, [id, req.companyId]);
    if (!folder.rows[0]) throw new HttpError(404, 'Папка не найдена');
    const removed = await client.query(`DELETE FROM documents WHERE folder_id = $1 AND company_id = $2 RETURNING file_path`, [id, req.companyId]);
    await client.query(`DELETE FROM document_folders WHERE id = $1`, [id]);
    return removed.rows;
  });
  files.forEach((f) => removeUploadedFile(f.file_path));
  res.json({ success: true });
}));

api.get('/documents/files', h(async (req, res) => {
  const conds = ['d.company_id = $1'];
  const vals = [req.companyId];
  if (isUuid(req.query.folderId)) {
    vals.push(req.query.folderId);
    conds.push(`d.folder_id = $${vals.length}`);
  }
  if (str(req.query.search)) {
    vals.push(`%${str(req.query.search)}%`);
    conds.push(`d.name ILIKE $${vals.length}`);
  }
  const result = await pool.query(
    `SELECT d.*, u.full_name AS uploaded_by_name FROM documents d LEFT JOIN users u ON u.id = d.uploaded_by
     WHERE ${conds.join(' AND ')} ORDER BY d.created_at DESC LIMIT 500`,
    vals
  );
  res.json({ data: result.rows.map(documentOut) });
}));

api.post('/documents/upload', upload.single('file'), h(async (req, res) => {
  if (!req.file) throw new HttpError(400, 'Файл не выбран');
  let folderId = null;
  if (isUuid(req.body.folderId)) {
    const folder = await pool.query(`SELECT id FROM document_folders WHERE id = $1 AND company_id = $2`, [req.body.folderId, req.companyId]);
    if (!folder.rows[0]) {
      removeUploadedFile(req.file.filename);
      throw new HttpError(404, 'Папка не найдена');
    }
    folderId = folder.rows[0].id;
  }
  const original = originalName(req.file);
  const ext = path.extname(original).replace('.', '').toLowerCase();
  const result = await pool.query(
    `INSERT INTO documents (company_id, folder_id, name, file_path, file_size, file_type, uploaded_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
    [req.companyId, folderId, original, `/uploads/${req.file.filename}`, req.file.size, ext, req.user.id]
  );
  res.status(201).json({ data: documentOut(result.rows[0]) });
}));

const handleDeleteDocument = h(async (req, res) => {
  const result = await pool.query(`DELETE FROM documents WHERE id = $1 AND company_id = $2 RETURNING file_path`, [uuidOrNull(req.params.id), req.companyId]);
  if (!result.rows[0]) throw new HttpError(404, 'Файл не найден');
  removeUploadedFile(result.rows[0].file_path);
  res.json({ success: true });
});
api.delete('/documents/files/:id', handleDeleteDocument);
api.delete('/documents/:id', handleDeleteDocument);

// ============================================================================
// NOTIFICATIONS
// ============================================================================
async function notify(userId, title, body, type = 'SYSTEM', referenceId = null) {
  if (!isUuid(userId)) return;
  let inserted;
  try {
    inserted = await pool.query(
      'INSERT INTO notifications (user_id, title, body, type, reference_id) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [userId, title, body, type, uuidOrNull(referenceId)]
    );
  } catch (err) {
    console.error('Notification insertion error:', err.message);
    return;
  }
  // Push to the user's iPhones in the background; the request does not wait for Apple.
  pushToUser(userId, { title, body, type, referenceId, notificationId: inserted.rows[0].id }).catch((err) => {
    console.error('Push error:', err.message);
  });
}

async function pushToUser(userId, { title, body, type, referenceId, notificationId }) {
  if (!apns.enabled) return;
  const user = await pool.query('SELECT push_enabled FROM users WHERE id = $1', [userId]);
  if (!user.rows[0] || !user.rows[0].push_enabled) return;
  const devices = await pool.query(`SELECT token, environment FROM device_tokens WHERE user_id = $1 AND platform = 'ios'`, [userId]);
  if (devices.rows.length === 0) return;
  const unread = await pool.query('SELECT count(*)::int AS n FROM notifications WHERE user_id = $1 AND NOT is_read', [userId]);
  for (const d of devices.rows) {
    const result = await apns.send(d.token, {
      title, body, badge: unread.rows[0].n, environment: d.environment,
      data: { type, referenceId: referenceId || null, notificationId },
    });
    if (result.unregistered) await pool.query('DELETE FROM device_tokens WHERE token = $1', [d.token]);
    else if (!result.ok && !result.skipped) console.error(`APNs ${result.status || ''} ${result.reason || ''}`.trim());
  }
}

api.get('/notifications', h(async (req, res) => {
  const result = await pool.query('SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100', [req.user.id]);
  res.json({ data: out(result.rows) });
}));

api.get('/notifications/since', h(async (req, res) => {
  const since = new Date(String(req.query.after || ''));
  if (Number.isNaN(since.getTime())) throw new HttpError(400, 'Укажите время');
  const result = await pool.query(
    `SELECT * FROM notifications WHERE user_id = $1 AND NOT is_read AND created_at > $2 ORDER BY created_at ASC LIMIT 20`,
    [req.user.id, since.toISOString()]
  );
  res.json({ data: out(result.rows) });
}));

api.get('/notifications/unread', h(async (req, res) => {
  const result = await pool.query('SELECT count(*)::int AS n FROM notifications WHERE user_id = $1 AND NOT is_read', [req.user.id]);
  res.json({ count: result.rows[0].n });
}));

api.post('/notifications/read-all', h(async (req, res) => {
  await pool.query('UPDATE notifications SET is_read = TRUE WHERE user_id = $1', [req.user.id]);
  res.json({ success: true });
}));

api.patch('/notifications/:id/read', h(async (req, res) => {
  await pool.query('UPDATE notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2', [uuidOrNull(req.params.id), req.user.id]);
  res.json({ success: true });
}));

api.delete('/notifications/:id', h(async (req, res) => {
  await pool.query('DELETE FROM notifications WHERE id = $1 AND user_id = $2', [uuidOrNull(req.params.id), req.user.id]);
  res.json({ success: true });
}));

// ============================================================================
// ERRORS
// ============================================================================
app.use((req, res) => {
  res.status(404).json({ message: `Маршрут ${req.originalUrl.split('?')[0]} не найден` });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE' ? 'Файл слишком большой (максимум 25 МБ)' : 'Не удалось принять файл';
    return res.status(400).json({ message });
  }
  if (err && err.status === 404 && req.path.startsWith('/uploads')) return res.status(404).json({ message: 'Файл не найден' });
  if (err instanceof HttpError) return res.status(err.status).json({ message: err.message });
  if (err && err.type === 'entity.parse.failed') return res.status(400).json({ message: 'Некорректный запрос' });
  if (err && err.code === '23505') return res.status(400).json({ message: 'Такая запись уже существует' });
  if (err && err.code === '23503') return res.status(400).json({ message: 'Запись используется в других документах' });
  console.error(`💥 ${req.method} ${req.originalUrl}:`, err);
  res.status(500).json({ message: 'Внутренняя ошибка сервера. Попробуйте ещё раз' });
});

if (require.main === module) {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 COMPANY OS Server running on port ${PORT}`);
  });
}

module.exports = { app, server, pool };

// Sets a user's password directly in the database.
//   DB_HOST=... DB_PASSWORD=... node scripts/set-password.js user@example.com 'NewPassword'
// Needed once after upgrading: the old server accepted shared master passwords,
// which no longer work, so accounts that relied on them need a real password.
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const [email, password] = process.argv.slice(2);
if (!email || !password || password.length < 6) {
  console.error('Usage: node scripts/set-password.js <email> <password (6+ characters)>');
  process.exit(1);
}

const pool = new Pool({
  host: process.env.DB_HOST || '172.17.0.5',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'company_os',
  user: process.env.DB_USER || 'company_os_user',
  password: process.env.DB_PASSWORD || 'company_os_password_2026',
});

(async () => {
  const hash = await bcrypt.hash(password, 10);
  const res = await pool.query(
    `UPDATE users SET password_hash = $1, token_version = token_version + 1, updated_at = CURRENT_TIMESTAMP
     WHERE LOWER(email) = LOWER($2) RETURNING email, full_name`,
    [hash, email]
  );
  if (res.rows.length === 0) {
    console.error(`No user with email ${email}`);
    process.exitCode = 1;
  } else {
    console.log(`Password updated for ${res.rows[0].full_name} <${res.rows[0].email}>`);
  }
  await pool.end();
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});

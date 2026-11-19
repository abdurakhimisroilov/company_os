// Apple Push Notification service client (token-based auth, HTTP/2), no Firebase.
//
// Configure with environment variables:
//   APNS_KEY_FILE   path to the AuthKey_XXXXXXXXXX.p8 file (or APNS_KEY with its contents)
//   APNS_KEY_ID     the 10-character Key ID shown next to the key in the Apple Developer portal
//   APNS_TEAM_ID    Apple Developer Team ID
//   APNS_BUNDLE_ID  the app's bundle identifier (topic)
// Without them, push is disabled and send() resolves to { skipped: true }.
const http2 = require('http2');
const fs = require('fs');
const jwt = require('jsonwebtoken');

const HOSTS = {
  production: 'https://api.push.apple.com',
  sandbox: 'https://api.sandbox.push.apple.com',
};

function loadKey() {
  if (process.env.APNS_KEY) return process.env.APNS_KEY.replace(/\\n/g, '\n');
  if (process.env.APNS_KEY_FILE && fs.existsSync(process.env.APNS_KEY_FILE)) return fs.readFileSync(process.env.APNS_KEY_FILE, 'utf8');
  return null;
}

const config = {
  key: loadKey(),
  keyId: process.env.APNS_KEY_ID,
  teamId: process.env.APNS_TEAM_ID,
  topic: process.env.APNS_BUNDLE_ID || 'com.companyos.companyOs',
};

const enabled = Boolean(config.key && config.keyId && config.teamId);
if (!enabled) console.warn('⚠️  APNs is not configured (APNS_KEY_FILE, APNS_KEY_ID, APNS_TEAM_ID): iPhone push is off.');

// Apple accepts a provider token for up to an hour and rejects refreshing it
// more often than every 20 minutes, so it is reused for 50 minutes.
let cachedToken = null;
let cachedAt = 0;
function providerToken() {
  const now = Math.floor(Date.now() / 1000);
  if (!cachedToken || now - cachedAt > 50 * 60) {
    // jsonwebtoken adds "iat" itself; Apple requires it.
    cachedToken = jwt.sign({ iss: config.teamId }, config.key, {
      algorithm: 'ES256',
      header: { alg: 'ES256', kid: config.keyId },
    });
    cachedAt = now;
  }
  return cachedToken;
}

const sessions = {};
function session(environment) {
  const existing = sessions[environment];
  if (existing && !existing.closed && !existing.destroyed) return existing;
  const s = http2.connect(HOSTS[environment] || HOSTS.production);
  s.on('error', () => { delete sessions[environment]; });
  s.on('close', () => { delete sessions[environment]; });
  s.setTimeout(10 * 60 * 1000, () => s.close());
  sessions[environment] = s;
  return s;
}

/**
 * Sends one alert. Resolves to { ok, status, reason, unregistered } and never
 * rejects, so a push failure can never break the request that triggered it.
 */
function send(deviceToken, { title, body, badge, data, environment = 'production' }) {
  if (!enabled) return Promise.resolve({ ok: false, skipped: true });
  return new Promise((resolve) => {
    let req;
    try {
      req = session(environment).request({
        ':method': 'POST',
        ':path': `/3/device/${deviceToken}`,
        authorization: `bearer ${providerToken()}`,
        'apns-topic': config.topic,
        'apns-push-type': 'alert',
        'apns-priority': '10',
      });
    } catch (err) {
      resolve({ ok: false, reason: err.message });
      return;
    }
    let status = 0;
    let raw = '';
    req.setEncoding('utf8');
    req.on('response', (headers) => { status = headers[':status']; });
    req.on('data', (chunk) => { raw += chunk; });
    req.on('end', () => {
      let reason = null;
      try { reason = raw ? JSON.parse(raw).reason : null; } catch (e) { reason = raw; }
      resolve({
        ok: status === 200,
        status,
        reason,
        // The token belongs to an uninstalled app or another environment.
        unregistered: status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered' || reason === 'DeviceTokenNotForTopic',
      });
    });
    req.on('error', (err) => resolve({ ok: false, reason: err.message }));
    req.setTimeout(15000, () => { req.close(); resolve({ ok: false, reason: 'timeout' }); });
    req.end(JSON.stringify({
      aps: { alert: { title, body }, sound: 'default', ...(Number.isInteger(badge) ? { badge } : {}) },
      ...(data || {}),
    }));
  });
}

module.exports = { send, enabled };

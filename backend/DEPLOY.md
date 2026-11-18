# Deploying the COMPANY OS server

The production process is `standalone-server.js` (Express + PostgreSQL). The NestJS
code under `src/` is not used at runtime; only `src/database/schema.sql` matters,
for creating a brand-new database.

## Upgrading the existing server

Do these in order. Steps 1–3 are safe to repeat.

1. **Back up the database.**
   `pg_dump -U company_os_user -d company_os -Fc -f company_os_$(date +%F).dump`
2. **Copy the new code** (`standalone-server.js`, `migrations/`, `scripts/`, `package.json`,
   `package-lock.json`) and run `npm ci --omit=dev`.
3. **Run the migration** as the database owner:
   `psql -U company_os_user -d company_os -v ON_ERROR_STOP=1 -f migrations/001_release_schema.sql`
   It adds the missing columns (including the three whose absence made every
   income/expense fail), creates organization membership, and assigns all existing
   rows and users to the first organization.
4. **Set the environment** (see below) and restart the process.
5. **Give administrators a real password.** The old server accepted three shared
   master passwords for any account; that is removed. Any account that was using
   one of them needs: `node scripts/set-password.js user@example.com 'NewPassword'`
6. **Verify:** `BASE_URL=http://localhost:3000 node test/api-e2e.js` (creates and
   deletes its own throwaway accounts; expects every check to pass).

## Creating a new database from scratch

```
psql -U company_os_user -d company_os -v ON_ERROR_STOP=1 -f src/database/schema.sql
psql -U company_os_user -d company_os -v ON_ERROR_STOP=1 -f migrations/001_release_schema.sql
```
Then register the first account in the app; it becomes the owner of its own organization.

## Environment

| Variable | Required | Notes |
|---|---|---|
| `JWT_SECRET` | yes | Long random string. The built-in fallback is public (it is in the git history); with it anyone can forge a session. Changing it signs everyone out once. |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | yes | Change the database password: the old one is in the git history. |
| `PORT` | no | Default 3000. |
| `PUBLIC_URL` | no | e.g. `https://api.example.com`. When set, file links are returned as absolute URLs. |
| `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN` | no | Defaults `7d` / `30d`. |

## Before the App Store build

- **Close PostgreSQL to the internet.** Port 5432 on the server currently accepts
  outside connections; bind it to localhost / the Docker network and firewall it.
- **Serve the API over HTTPS** behind a reverse proxy (nginx or Caddy with a
  certificate). iOS App Transport Security blocks plain `http://` unless the app
  ships an exception, and App Review asks for a justification of such exceptions.
  Then build the app with `--dart-define=API_BASE_URL=https://<domain>/api/v1`.
- **Keep `uploads/` on persistent storage** and include it in backups; uploaded
  documents live there.

## What changed for existing users

- Every request now needs a valid login; old app versions keep working only for
  the routes they already called with a token.
- Data is separated per organization. Everything that existed before the upgrade
  belongs to the first organization, and all existing users are its members.
- A person who registers themselves gets their own empty organization. To add
  someone to an existing organization, an administrator adds them in «Сотрудники»
  and passes on the one-time password shown there.

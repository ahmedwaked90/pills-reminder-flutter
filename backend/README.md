# Pills Reminder API — Laravel backend

Laravel 11 API for the Pills Reminder Flutter app:

- **Auth**: Google Sign-In via Laravel Socialite + Sanctum personal access tokens
- **Data**: medications CRUD, scoped per user
- **Sync**: last-write-wins per record with soft deletes

The Flutter app stays offline-first; the backend is the shared source of truth across devices.

---

## Requirements

- PHP **8.2+** (XAMPP 8.2 or 8.3 ships with this)
- Composer 2.x
- MySQL 5.7+ / MariaDB 10.3+ (XAMPP includes MariaDB)
- A Google Cloud OAuth 2.0 Client (free)

---

## Local setup with XAMPP

### 1. Start XAMPP

Open the XAMPP control panel and start **Apache** and **MySQL**.

### 2. Create the database

Open http://localhost/phpmyadmin, create a database called `pills_reminder`
(collation `utf8mb4_unicode_ci`). Or from the terminal:

```bash
# Windows XAMPP:
C:\xampp\mysql\bin\mysql.exe -u root -e "CREATE DATABASE pills_reminder CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
# macOS XAMPP:
/Applications/XAMPP/bin/mysql -u root -e "CREATE DATABASE pills_reminder CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

### 3. Install PHP dependencies

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

### 4. Google OAuth credentials

1. Go to https://console.cloud.google.com → create a project (or reuse one).
2. **APIs & Services → OAuth consent screen** — set up a Testing-mode consent screen, add your own Gmail as a test user.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - Create a **Web application** client. Add `http://127.0.0.1:8000/api/auth/google/callback` to the authorized redirect URIs.
   - Create an **Android** client for `com.moazsalem.pills_reminder` (you'll need your debug `SHA-1` from `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey` — password `android`).
   - (Optional) **iOS** client for the same bundle ID.
4. Paste the values into `backend/.env`:

```dotenv
GOOGLE_CLIENT_ID=XXXXXX.apps.googleusercontent.com          # the Web client id
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxx
GOOGLE_REDIRECT_URI=http://127.0.0.1:8000/api/auth/google/callback
# SPACE-separated list of ALL client IDs that are allowed to produce id_tokens
# that this server accepts — put the Android (and iOS) client IDs here.
GOOGLE_ALLOWED_AUDIENCES="XXXXXX-android.apps.googleusercontent.com XXXXXX-ios.apps.googleusercontent.com"
```

The Flutter app uses the Android/iOS client IDs to obtain a Google **ID token**, which it POSTs to `/api/auth/google`; the backend verifies the token's audience against `GOOGLE_CLIENT_ID` + `GOOGLE_ALLOWED_AUDIENCES`.

### 5. Migrate the database

```bash
php artisan migrate
```

### 6. Run it

Development server (easiest):

```bash
php artisan serve
# → http://127.0.0.1:8000
```

Behind XAMPP Apache instead: point `httpd-vhosts.conf` at `backend/public/`, or create a symlink from `htdocs/pills-api` → `backend/public/` and visit `http://localhost/pills-api/`.

Sanity check:

```bash
curl http://127.0.0.1:8000/
# {"name":"Pills Reminder API","status":"ok", ...}
```

---

## API reference

All endpoints return JSON. Authenticated endpoints require
`Authorization: Bearer <sanctum-token>`.

### `POST /api/auth/google`  — public

Exchange a Google ID token for a Sanctum token.

```jsonc
// request
{ "id_token": "<google ID token from Flutter google_sign_in>",
  "device_name": "pixel-8" }

// 200 response
{ "token": "1|abcdef...",
  "user":  { "id": 1, "name": "Ahmed",
             "email": "ahmed@example.com",
             "avatar_url": "https://lh3.googleusercontent.com/..." } }
```

### `GET /api/auth/me` — auth

```jsonc
{ "user": { "id": 1, "name": "...", "email": "...", "avatar_url": "..." } }
```

### `POST /api/auth/logout` — auth

Revokes the current token.

### `GET /api/medications` — auth

```jsonc
{ "data": [ { "id": 1, "client_uuid": "...", "name": "...", ... } ] }
```

### `POST /api/medications` — auth

```jsonc
// request
{
  "client_uuid": "7b3d-...",     // stable UUID generated on the client
  "name": "Ibuprofen 400mg",
  "frequency": "daily",           // "once" | "daily" | "weekly"
  "weekdays": [1,2,3,4,5],        // required when frequency = "weekly" (ISO: Mon=1)
  "times": ["08:00", "20:00"],    // HH:mm
  "start_date": "2026-11-18",
  "end_date": null,
  "dose": "1 tablet",
  "notes": null,
  "client_updated_at": "2026-11-18T09:00:00Z"
}
```

### `GET / PATCH / DELETE /api/medications/{id}` — auth

Standard REST. `DELETE` is a soft delete.

### `POST /api/sync` — auth

Last-write-wins sync. The client sends everything that changed on it
since `last_sync_at`, the server replies with everything that changed on
the server since that same time (including soft-deleted rows so the
client can tombstone them locally).

```jsonc
// request
{
  "since": "2026-11-17T22:00:00Z",   // null for first sync
  "changes": [
    { "client_uuid": "...", "deleted": false,
      "name": "...", "frequency": "daily", "times": ["08:00"],
      "start_date": "2026-11-18", "end_date": null,
      "dose": null, "notes": null,
      "client_updated_at": "2026-11-18T09:00:00Z" },
    { "client_uuid": "...", "deleted": true,
      "client_updated_at": "2026-11-18T09:01:00Z" }
  ]
}

// response
{
  "server_time": "2026-11-18T09:01:02Z",
  "applied":   ["<client_uuid>", ...],
  "rejected":  [{ "client_uuid": "...", "reason": "stale" }],
  "changes":   [ { ...row, "deleted": false }, { ...row, "deleted": true } ]
}
```

**Conflict rule**: for a given `client_uuid`, whichever side has the newer `client_updated_at` wins the whole record. A client write with `client_updated_at <= server's stored client_updated_at` is **rejected** (reported in `rejected`), and the client should overwrite its local copy with the server's version.

---

## Testing with curl

```bash
# 1. Get a Google ID token from any OAuth playground or the Flutter app, then:
TOKEN=$(curl -s http://127.0.0.1:8000/api/auth/google \
  -H 'Content-Type: application/json' \
  -d '{"id_token":"...","device_name":"curl-test"}' | jq -r .token)

# 2. Create a medication
curl http://127.0.0.1:8000/api/medications \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "client_uuid":"test-1","name":"Test pill","frequency":"daily",
    "times":["08:00"],"start_date":"2026-11-18",
    "client_updated_at":"2026-11-18T09:00:00Z"
  }'

# 3. List
curl http://127.0.0.1:8000/api/medications -H "Authorization: Bearer $TOKEN"
```

---

## Project layout

```
backend/
├── app/
│   ├── Http/Controllers/
│   │   ├── AuthController.php      # POST /auth/google, me, logout
│   │   ├── MedicationController.php
│   │   └── SyncController.php
│   ├── Models/
│   │   ├── User.php                # HasApiTokens (Sanctum)
│   │   └── Medication.php          # SoftDeletes
│   └── Providers/
├── bootstrap/
│   ├── app.php                     # Laravel 11 bootstrap, Sanctum middleware
│   └── providers.php
├── config/
│   └── services.php                # google driver config
├── database/migrations/
│   ├── 0001_01_01_* users, cache, jobs
│   ├── 2024_01_01_000000_create_personal_access_tokens_table.php
│   └── 2026_11_18_000000_create_medications_table.php
├── routes/
│   ├── api.php                     # all API routes
│   └── web.php
├── public/index.php
├── artisan
├── composer.json
└── .env.example
```

`vendor/` is pulled in by `composer install` and is `.gitignore`d.

---

## Troubleshooting

- **`SQLSTATE[HY000] [2002]`** — MySQL isn't running in XAMPP. Start it.
- **`could not find driver`** — your CLI PHP is a different one than XAMPP's. Call the XAMPP PHP explicitly: `C:\xampp\php\php.exe artisan migrate` or add XAMPP's `php` to your `PATH`.
- **Google token invalid** — check the `aud` claim on https://jwt.io matches one of `GOOGLE_CLIENT_ID` or `GOOGLE_ALLOWED_AUDIENCES`.
- **CORS from the Flutter web build** — add the `cors` middleware config in `config/cors.php` (publish it with `php artisan config:publish cors`) or restrict to the bundled-in API routes.

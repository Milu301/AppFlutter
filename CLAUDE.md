# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**COBROSAPP** is a multi-tenant loan/collections management system ("sistema de cobranzas") with three components:

| Component | Stack | Purpose |
|---|---|---|
| `cobrosapp-backend/` | Node.js + Express + PostgreSQL | REST API — the source of truth |
| `flutter_app/` | Flutter + Riverpod + Dio | Mobile app for vendors (Android-first) |
| `admin-web/` | React + Vite + Tailwind | Web dashboard for admins |

Production is deployed on **Railway**. See `DEPLOY_RAILWAY.txt` for the full deployment sequence.

---

## Backend (`cobrosapp-backend/`)

### Commands
```bash
npm run dev       # nodemon watch (development)
npm start         # node src/server.js (production)
node scripts/db_apply_sql.js  # apply a single SQL migration
```

No test runner is configured — there is no `npm test`.

### Architecture

**Feature-based layout:** each domain lives in `src/features/<name>/` with four files: `routes.js`, `controller.js`, `service.js`, `schema.js`. Business logic belongs exclusively in `service.js`; controllers only call services and send responses.

**Request pipeline (every protected route):**
```
apiLimiter → auth (JWT verify) → subscriptionGuard → roleGuard (optional) → validate(schema) → controller → service
```

**Response envelope — always `{ ok, data }` or `{ ok, error }`:**
- Success: `ok(res, data)` / `created(res, data)` from `src/utils/response.js`
- Failure: throw `new AppError(status, code, message)` — caught by `src/middlewares/errorHandler.js`

**Multi-tenancy model:**
- Every row is scoped to an `admin_id`. Services always verify `admin_id` ownership before mutating data.
- `req.auth` is set by `src/middlewares/auth.js` and contains `{ role, adminId, vendorId, tokenVersion }`.
- Vendor access to a client requires: same `vendor_id` on the client **or** the client being in an active route assignment for that vendor.

**Transactions:** Use `pool.connect()` + manual `BEGIN/COMMIT/ROLLBACK` for multi-table writes (see `credits/service.js`). The helper `src/db/tx.js:withTransaction(fn)` wraps this pattern.

**Subscription guard:** Every protected request checks `admins.subscription_expires_at` and `admins.status`. Vendors additionally have their own `status`, `deleted_at`, and `token_version` checked on every request.

**Vendor permissions:** Stored as JSONB on `vendors.permissions`. Check with the local `permTrue(permissions, key)` helper. Current keys: `canCreateClients`, `canCreateCredits`.

**Key environment variables:**
```
DATABASE_URL        PostgreSQL connection string
JWT_SECRET          Sign/verify JWTs
CORS_ORIGINS        Comma-separated origins or "*"
DB_SSL=true         Enable SSL for Supabase/Railway poolers
APP_TIMEZONE        Timezone for cash day-window queries (default: America/Bogota)
SUBSCRIPTION_ENABLED  Feature flag for subscription enforcement
RATE_LIMIT_ENABLED  Feature flag for rate limiting
```

### Database

Migrations live in `database/migrations/` and must be applied **in filename order**. There is no migration runner — apply them manually via psql or a GUI. The initial admin seed is in `database/seed/001_seed_admin.sql` (edit before first run).

Core tables: `admins`, `vendors`, `clients`, `routes`, `route_clients`, `route_assignments`, `route_visits`, `credits`, `installments`, `payments`, `admin_cash_movements`, `vendor_cash_movements`, `vendor_locations`, `audit_logs`.

**Cash movements are created automatically** by the credits service when a credit is disbursed or a payment is received. Do not insert them separately.

---

## Flutter App (`flutter_app/`)

### Commands
```bash
flutter pub get
flutter run                                     # run on connected device/emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000  # point to local backend
flutter build apk --release                     # build APK
flutter test                                    # run unit tests
```

### Architecture

**State management:** Riverpod (`flutter_riverpod`). All top-level providers are declared in `lib/app_providers.dart`.

**Auth flow (`lib/core/auth/`):**
- `AuthController` (StateNotifier) holds `AuthState` with an `AuthStatus` enum.
- `main.dart:RootGate` switches the entire widget tree based on `AuthStatus`.
- On 401 responses, `ApiClient` emits `UnauthorizedEvent` on `AppBus` → `AuthController` calls `logout()`.
- On 403 + `SUBSCRIPTION_EXPIRED` / `DEVICE_MISMATCH`, `ApiClient` emits `BlockingAuthEvent` → `AuthController` transitions to a blocking screen without clearing navigation manually.

**Session persistence:** `SessionRepository` uses `flutter_secure_storage` (Android encrypted shared preferences). `SessionStore` is an in-memory singleton read synchronously by the Dio interceptor to attach the Bearer token.

**API client (`lib/core/api/api_client.dart`):** Wraps Dio. The backend always returns `{ ok, data }` — unwrapping is done inside each method. The `AppConfig.api` base URL is set by `--dart-define=API_BASE_URL` at build time; the default points to the Railway production URL.

**Location tracking:** `LocationController` starts background GPS pings every `AppConfig.locationInterval` (3 min) when a vendor session is active. It stops automatically on logout.

**Feature organization:**
- `lib/features/auth/` — login screens (vendor + admin)
- `lib/features/vendor/` — vendor home with tabs: dashboard, route day, clients, payments, cash, profile
- `lib/features/admin/` — admin home with tabs: vendors, clients, routes, cash, reports, settings
- `lib/features/common/` — shared sheets used by both roles (credit form, payment form, client detail, receipt)
- `lib/features/blocked/` — full-screen blockers for expired subscription / device mismatch

**Currency:** `CurrencyNotifier` (in `app_providers.dart`) persists the user's display currency preference in secure storage. It is display-only — all amounts stored/transmitted in the credit's `currency_code`.

---

## Admin Web (`admin-web/`)

### Commands
```bash
npm run dev       # Vite dev server
npm run build     # production build → dist/
npm run preview   # serve dist/ locally
```

Set `VITE_API_URL` in a `.env` file to point to the backend (defaults to `http://localhost:3000/api`).

### Architecture

**Shared utilities:**
- `src/utils/formatters.js` — `currency()`, `fmt()`, `pct()`, `formatDate()`, `formatDateTime()`. Import from here; do not define local formatters in pages.
- `src/components/Toast.jsx` — inline toast component + `useToast()` hook. Pages use `const [toast, showToast] = useToast()` and render `{toast}` where the notification appears.

**Auth:** `src/contexts/AuthContext.jsx` stores the JWT in `localStorage` under key `cobros_token`. The axios interceptor in `src/api/client.js` attaches it automatically and redirects to `/` on 401.

**API layer:** `src/api/client.js` exports named groups (`authAPI`, `adminAPI`, `vendorAPI`, `clientAPI`). The response interceptor automatically unwraps the `{ ok, data }` envelope so pages receive the payload directly.

**Routing:** React Router v6, all routes under `<Layout>` are protected by `ProtectedRoute`. Admin session is required for all pages.

**No global state library** — all data fetching is local component state (`useState` + `useEffect`).

---

## Cross-cutting Concerns

**Token versioning:** When an admin resets a vendor's device or password, `vendors.token_version` is incremented. The vendor's JWT carries `tv` (token version); `subscriptionGuard` rejects the request if `tv !== current`, forcing re-login.

**Soft deletes:** Vendors and clients use `deleted_at IS NULL` filters everywhere. Never hard-delete these rows.

**Monetary arithmetic:** All money calculations use integer cent arithmetic (`Math.round(amount * 100)`) to avoid floating-point errors. Final values are stored and returned as `float8`/`DECIMAL`.

**Audit logs:** Call `auditLog({...})` for significant actions (login, subscription expiry blocks). Failures are caught and logged as warnings — never let audit failures break the main flow.

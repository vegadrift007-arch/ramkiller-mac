# Clerk Auth Integration — Design Spec
**Date:** 2026-05-03  
**Project:** VannaQ (Gammabot)  
**Status:** Approved for implementation

---

## Goal

Replace the shared Basic Auth gate with a real per-user authentication system using Clerk. Unauthenticated visitors can view the public landing page and legal pages; any attempt to access a dashboard or research page redirects to Clerk's sign-in flow.

---

## Constraints

- H-1B pre-revenue: no payment flows in this spec (Stripe is Phase 3b)
- Stack: plain HTML + FastAPI + SQLite — no Node.js / bundler
- Clerk app: `VannaQ`, Development instance `advanced-gnat-21.clerk.accounts.dev`
- Sign-in methods: Email + Google OAuth
- Publishable key: `pk_test_YWR2YW5jZWQtZ25hdC0yMS5jbGVyay5hY2NvdW50cy5kZXYk`
- Secret key: stored in VPS `.env` as `CLERK_SECRET_KEY` (never committed)

---

## Architecture: Two-layer auth

```
Browser request to vannaq.com/research/gamma
        │
        ▼
CF Pages _middleware.js (edge)
  ├─ Public path? → pass through
  ├─ __session cookie present? → pass through
  └─ No cookie → 302 redirect to /sign-in?redirect_url=/research/gamma
        │
        ▼ (authenticated request)
Dashboard HTML loads, initializes Clerk JS SDK (CDN)
util.js: clerk.session.getToken() → Bearer token
        │
        ▼
api.vannaq.com/api/* (VPS FastAPI)
  clerk_jwt_gate middleware
  ├─ No Authorization header → 401
  ├─ Invalid JWT → 401
  └─ Valid JWT → extract sub (clerk_user_id), upsert users table, continue
```

---

## Files changed

### 1. `functions/_middleware.js`

Replace Basic Auth logic with Clerk session cookie check.

**Public paths** (unchanged): `/`, `/index.html`, legal pages, robots, sitemap, favicon, `/assets/*`, `/sign-in`, `/sign-in.html`

**All other paths**: check for `__session` cookie.
- Present → `next()` (pass through; API layer does cryptographic verification)
- Absent → `Response.redirect(/sign-in?redirect_url=<original_path>, 302)`

No CLERK_SECRET_KEY needed in CF Workers — cookie presence is a UX gate only. Cryptographic auth lives in api.py.

### 2. `sign-in.html` (new file, CF Pages root)

Single-purpose page that mounts the Clerk `<SignIn />` component.

- Loads Clerk CDN: `https://cdn.jsdelivr.net/npm/@clerk/clerk-js@latest/dist/clerk.browser.js`
- Initializes: `new Clerk(PUBLISHABLE_KEY)` → `clerk.load()`
- After load: if already signed in → redirect to `redirect_url` param (or `/research/gamma`)
- If not signed in: `clerk.mountSignIn(el, { routing: 'virtual', redirectUrl })`
- Styled to match VannaQ dark theme

### 3. `assets/util.js`

Add Clerk token injection into the existing `_fetchT` function.

**New at top of file:**
```js
const CLERK_PUBLISHABLE_KEY = 'pk_test_YWR2YW5jZWQtZ25hdC0yMS5jbGVyay5hY2NvdW50cy5kZXYk';
let _clerk = null;
let _clerkReady = false;
```

**New `_initClerk()` function:**
- Waits for `window.Clerk` to be available (exponential backoff, max 5s)
- Calls `clerk.load()`
- Sets `_clerk = clerk`, `_clerkReady = true`
- If `!clerk.user` after load AND `window.location.pathname !== '/sign-in'` → redirect to `/sign-in?redirect_url=<current path>` (guards against infinite redirect loop)

**Updated `_fetchT()`:**
- Before fetch, if `_clerkReady` and endpoint starts with `API_BASE + '/api'`:
  - `const token = await _clerk.session.getToken()`
  - Inject `Authorization: Bearer ${token}` header

**`_initClerk()` is called once** at module load time (async IIFE).

### 4. Dashboard HTML files (7 files, one-line change each)

Add Clerk CDN `<script>` tag in `<head>`, before `util.js`:

```html
<script src="https://cdn.jsdelivr.net/npm/@clerk/clerk-js@latest/dist/clerk.browser.js" crossorigin="anonymous"></script>
```

Affected files:
- `research/gamma.html`
- `research/delta.html`
- `research/vanna.html`
- `research/flow.html`
- `research/state.html`
- `option.html`
- `flow.html`

### 5. `api.py` — JWT middleware

New middleware `clerk_jwt_gate` inserted after existing `api_origin_gate`:

```
Exempt paths: /api/health, /ws/* (WebSocket handled separately)
For all /api/* requests:
  1. Extract Authorization: Bearer <token>
  2. Fetch JWKS from https://advanced-gnat-21.clerk.accounts.dev/.well-known/jwks.json
     (cached in memory, refreshed every 12h)
  3. Verify JWT: signature, exp, iss (clerk.com/oauth/authorize)
  4. Extract sub → clerk_user_id
  5. Upsert into users table (clerk_user_id, created_at) — ignore if exists
  6. Set request.state.clerk_user_id
  7. On failure → JSONResponse({"error": "Unauthorized"}, status_code=401)
```

**Dependencies to add to VPS:**
- `PyJWT[crypto]` (JWT decode + JWKS verification)
- `cryptography` (RSA key support, likely already installed)

**JWKS cache:**
```python
_jwks_cache: dict = {"keys": [], "fetched_at": 0}
JWKS_TTL = 43200  # 12 hours
```

### 6. `db.py` — users table

Add to schema initialization:

```sql
CREATE TABLE IF NOT EXISTS users (
    clerk_user_id TEXT PRIMARY KEY,
    email         TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    paid          INTEGER NOT NULL DEFAULT 0
);
```

`paid` column is for future Stripe integration (Phase 3b). Always 0 for now.

### 7. Environment variables

**VPS `/opt/gammabot/.env`** (via SSH):
```
CLERK_SECRET_KEY=sk_test_...   # user holds this, not committed
```

**CF Pages env vars** (Cloudflare dashboard):
- No Clerk vars needed on CF side (cookie check is presence-only, no secret required)

---

## Auth flow: end-to-end

### Sign-in
1. User clicks "Research → Gamma" on landing
2. CF middleware: no `__session` cookie → redirect `/sign-in?redirect_url=/research/gamma`
3. `/sign-in` page loads, Clerk mounts SignIn component
4. User signs in (email or Google)
5. Clerk sets `__session` cookie (HttpOnly, Secure, SameSite=Lax)
6. Redirect to `/research/gamma`

### Authenticated dashboard use
1. CF middleware: `__session` present → pass through
2. Dashboard HTML loads, Clerk CDN script loads
3. `util.js` `_initClerk()` runs: `clerk.load()` → verifies session, gets user
4. API calls: `_fetchT` attaches `Authorization: Bearer <jwt>`
5. `api.py` `clerk_jwt_gate`: verifies JWT via JWKS → proceeds

### Sign-out
- `clerk.signOut()` → Clerk clears `__session` cookie
- Next dashboard visit → CF middleware redirects to `/sign-in`

### WebSocket (`/ws/gex`)
- WS does not support `Authorization` headers natively
- Pass Clerk token as query param: `/ws/gex?token=<jwt>`
- `util.js` appends token when constructing the WS URL
- api.py WS handler reads `token` query param, verifies via JWKS on connection; rejects with close code 4401 if invalid

---

## Security properties

| Threat | Mitigation |
|--------|-----------|
| Unauthenticated dashboard HTML access | CF middleware cookie gate (fast 302) |
| Unauthenticated API data access | api.py JWKS JWT verification (cryptographic) |
| Expired tokens | JWT `exp` claim verified; Clerk auto-refreshes session |
| Token tampering | RSA signature verified against Clerk JWKS |
| Credential brute-force | Handled entirely by Clerk |
| CSRF | Clerk uses SameSite=Lax cookies + token-based API auth |

---

## Out of scope (Phase 3b)

- Stripe Checkout + paid gating
- `/api/*` endpoints that are paid-only
- User dashboard / account management page
- Email welcome sequence

---

## Rollout order

1. Add `users` table to db.py + deploy schema to VPS
2. Add JWT middleware to api.py + install PyJWT on VPS
3. Create `sign-in.html` + update `_middleware.js`
4. Update `assets/util.js` (add Clerk init + token injection)
5. Add Clerk CDN `<script>` to 7 dashboard HTML files
6. Git push (triggers CF Pages rebuild) + scp changed files to VPS
7. Test: sign-in flow, API calls with token, WS connection
8. Switch Clerk from Development → Production instance (generates `pk_live_` key)

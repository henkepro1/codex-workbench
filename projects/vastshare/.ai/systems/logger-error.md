# Logger & Error Handling

## Overview
Cross-cutting infrastructure: a singleton `Logger` on both backend and mobile with 5 levels (`Info / Success / Warn / Error / Debug`), redaction of common secret keys, and a never-crash error pipeline. Backend errors become `{ ok:false, code, userMessageKey, meta? }` payloads; mobile shows them via Toast and `handleApiError`. React render errors are caught by `ErrorBoundary`.

## How It Works

### Backend Logger (`apps/api/src/logger/Logger.ts`)
- Module-level `new LoggerImpl()` exported as `Logger`.
- Each call emits a colour-coded console line `[LEVEL] <ISO ts> <message> <jsonMeta>` and a JSONL file write to `logs/api-<day>.log`.
- `Logger.Error(message, error?)` — if `error instanceof Error`, captures `name / message / stack` into meta.
- `Logger.Debug` is suppressed unless `NODE_ENV !== "production"` or `LOG_DEBUG=1`.
- Redaction: keys `password / passwordHash / token / accessToken / refreshToken / jwt / authorization / cookie / secret` become `"[redacted]"` recursively, up to depth 4.

### Mobile Logger (`apps/mobile/src/logger/Logger.ts`)
- Same API but logs to console (RN console / browser devtools) and keeps an in-memory ring buffer of last 200 entries.
- `Logger.dump()` returns the buffer for a future "Send debug report" action.
- `__DEV__` gates `Debug`.

### Backend `AppError` (`apps/api/src/errors/AppError.ts`)
- Static factories: `validation / unauthorized / forbidden / notFound / conflict / rateLimited / badRequest / internal`.
- Carries `code`, `status`, `userMessageKey`, optional `meta`.
- `userMessageKey` is an i18n key like `errors.invalid_credentials` — the mobile side translates it.

### Backend `errorHandler` (`apps/api/src/errors/errorHandler.ts`)
Fastify `setErrorHandler` registered in `server.ts`. Flow:
1. `AppError` → `Logger.Warn` + safe payload.
2. Zod `ZodError` → coerce to `AppError.validation` with `meta.issues`.
3. Fastify validation (`err.statusCode < 500`) → safe `{code, userMessageKey:"errors.bad_request"}` payload.
4. Anything else → `Logger.Error("Unhandled error …", err)` + 500 with `userMessageKey:"errors.internal"`. Never leaks the underlying error message.

`setNotFoundHandler` returns `{ok:false, code:"not_found", userMessageKey:"errors.not_found", meta:{path}}`.

### Mobile `ErrorBoundary` (`src/errors/ErrorBoundary.tsx`)
React class component. `componentDidCatch` → `Logger.Error("React render error", {error, componentStack})`. Renders a fallback screen with localised title + body + Försök igen button that resets `hasError`.

### Mobile `handleApiError` + `Toast`
`src/lib/handleApiError.ts::toUserMessageKey(err)`:
- `err instanceof AppError` → return `err.userMessageKey`.
- Else `Logger.Warn("Unmapped error", …)` and return `"errors.internal"`.

`Toast` component (provider in `app/_layout.tsx`) shows the translated message at the bottom. Used everywhere via `useToast().showError(key)`.

### Never-crash process hooks
`server.ts::start` installs:
- `process.on("unhandledRejection", reason → Logger.Error("unhandledRejection", reason))`
- `process.on("uncaughtException", err → Logger.Error("uncaughtException", err))`
- `SIGINT` / `SIGTERM` → graceful close + `disconnectPrisma` + `exit 0`.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/logger/Logger.ts` | Backend singleton |
| `apps/api/src/errors/AppError.ts` | Typed app errors |
| `apps/api/src/errors/errorHandler.ts` | Fastify hook |
| `apps/mobile/src/logger/Logger.ts` | Mobile singleton + ring buffer |
| `apps/mobile/src/errors/AppError.ts` | Mobile AppError mirror |
| `apps/mobile/src/errors/ErrorBoundary.tsx` | React render guard |
| `apps/mobile/src/lib/handleApiError.ts` | Backend payload → i18n key |
| `apps/mobile/src/components/Toast.tsx` | User-visible toast (3 kinds) |

## Integration Points
- `i18n/locales/sv.json` + `en.json` `errors.*` keys are the canonical translation table.
- All thrown errors in services should be `AppError.*` — anything else is treated as a 500.
- Logger redaction means it's safe to pass entire request bodies / response objects to `Logger.Error`.

## Known issues / future work
- No log shipping (Sentry / Loki / etc.) — only local files + console.
- Mobile ring buffer is never sent anywhere — wire a "Send debug report" action under Profil > Support.
- No structured request-id correlation between backend log lines and the client request.

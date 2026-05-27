# Auth

## Overview
Email + password authentication with Argon2id hashing and JWT access (15m) + refresh (30d default, 90d when "remember me"). Refresh tokens are rotated on every use; the previous one is revoked. Soft-delete on account removal scrambles the email so the address can be re-registered.

## How It Works

### Register
`auth.service.ts::register` checks `User.email` uniqueness, hashes the password with `argon2id` (memory cost 19456, time cost 2), creates the user, then calls `issueTokens` (private helper) to create the access + refresh pair and persist a `RefreshToken` row with `tokenHash = sha256(jti)`.

### Login
`auth.service.ts::login` resolves the user by lowercase email, rejects deleted accounts, verifies the password via `argon2.verify`, then issues a fresh token pair. `remember=true` swaps in the long TTL (`JWT_REFRESH_TTL_REMEMBER_SECONDS`, default 90 days).

### Refresh (rotation)
`auth.service.ts::refresh`:
1. `verifyRefreshToken(token)` checks the JWT signature + claims.
2. Looks up the stored `RefreshToken` by `tokenHash`.
3. If missing / revoked / expired → throws `AppError.unauthorized("errors.session_expired")`.
4. Marks the row `revokedAt = now` (rotation) and issues a brand-new pair.
The HTTP cookie `refresh_token` is httpOnly + sameSite=lax. Mobile client uses an axios 401-interceptor that silently calls `/auth/refresh` and retries the original request once.

### Delete account
`auth.service.ts::deleteAccount` requires the current password, marks `deletedAt = now`, scrambles the email to `deleted-{userId}@local.invalid`, and revokes every outstanding refresh token in one `prisma.$transaction`.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/auth/hash.ts` | `hashPassword` / `verifyPassword` Argon2id wrappers |
| `apps/api/src/auth/jwt.ts` | sign/verify access + refresh, sha256 jti hashing |
| `apps/api/src/auth/auth.schemas.ts` | zod request body schemas |
| `apps/api/src/auth/auth.service.ts` | register / login / refresh / logout / deleteAccount |
| `apps/api/src/auth/auth.routes.ts` | Fastify route registrations + refresh-cookie setter |
| `apps/api/src/middleware/authenticate.ts` | `Bearer` access-token preHandler — attaches `req.user.id` |
| `apps/mobile/src/state/auth.store.ts` | zustand store (user + accessToken + avatarBase64), AsyncStorage persisted |
| `apps/mobile/src/api/client.ts` | axios + 401-silent-refresh + auto-logout |
| `apps/mobile/app/(auth)/login.tsx` · `register.tsx` | UI |
| `apps/api/tests/auth.test.ts` | full register→login→refresh→delete flow |

## Integration Points
- Listens to env: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_TTL_SECONDS`, `JWT_REFRESH_TTL_SECONDS`, `JWT_REFRESH_TTL_REMEMBER_SECONDS`. All validated via `apps/api/src/config/env.ts`.
- The `User.avatarBase64` column is updated by `PATCH /me/profile` from the avatar-picker flow (see [[design-system]] and the Profil > Inställningar screen).
- Cookies use `secure: true` in production only.

## Known issues / future work
- No email verification yet (the email field is trusted at signup).
- No password reset flow yet.
- No rate-limiting on `/auth/login` — a brute-force attack on a single account is currently possible. Add a Fastify-rate-limit plugin per route before going live.

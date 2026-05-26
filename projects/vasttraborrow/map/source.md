# Source

Source path: `D:\GameProjects\vasttraborrow`

pnpm monorepo.

## apps/api (Fastify + Prisma)

- `src/server.ts` — entrypoint; `buildServer()` is reusable from tests/extension code.
- `src/config/env.ts` — zod-validated env loader. Fails fast on missing JWT secrets etc.
- `src/logger/Logger.ts` — singleton `Logger` with `.Info` / `.Success` / `.Warn` / `.Error` / `.Debug`.
- `src/errors/AppError.ts` + `errorHandler.ts` — every thrown error becomes a safe `{ code, userMessageKey }` payload. No internals leak.
- `src/auth/` — register, login, refresh (rotation), logout, delete-me. Argon2id + JWT.
- `src/cards/` — user-owned `VtCard` CRUD.
- `src/listings/` — create/cancel listings, market snapshot (live prices per card type + tier).
- `src/pricing/PricingEngine.ts` — **pure** function `priceFor({config, tier, pendingCount}) → priceSek`. Unit-tested in `tests/pricing.test.ts`.
- `src/matching/MatchingService.ts` — FIFO match with 4-unique-recipients/month cap. Uses Postgres `FOR UPDATE SKIP LOCKED` for concurrency. Tests in `tests/matching.test.ts`.
- `src/fees/feeConfig.ts` — `computeFee(amount)` → `{ amount, fee, payout, feePct }`. `PLATFORM_FEE_PCT` env-driven, default 10%.
- `src/payments/` — `PaymentProvider` interface + `FakeProvider` (active) + `SwishProvider` (stub with explicit TODO list).
- `src/vt/` — Västtrafik PlaneraResa client (OAuth2 client-credentials), `/vt/locations` + `/vt/plan`, in-DB cache, zone-to-cardtype recommendation.
- `prisma/schema.prisma` — User, RefreshToken, AuditLog, VtCard, Listing, LenderRecipient, PaymentIntent, CardPriceConfig, VtRouteCache.
- `prisma/seed.ts` — upserts `CardPriceConfig` for all known card types.

## apps/mobile (Expo Router)

- `app/_layout.tsx` — root providers, ErrorBoundary, hydrates auth + prefs stores.
- `app/(auth)/{login,register}.tsx` — auth screens.
- `app/(tabs)/_layout.tsx` — bottom tabs: home, route-planner, my-loans, my-card, profile.
- `app/(tabs)/home.tsx` — market snapshot with live prices per card type + tier.
- `app/(tabs)/route-planner.tsx` — origin/destination → recommended card type → "Find lenders" deep-link.
- `app/(tabs)/my-loans.tsx` — as-lender + as-buyer history; consumes `?match=...&tier=...` deep-link to trigger matching.
- `app/(tabs)/my-card.tsx` — register a card, list it (Standard / Fast Sell), remove it.
- `app/(tabs)/profile.tsx` — language switch, theme switch (system/light/dark), logout, delete account.
- `src/logger/Logger.ts` — singleton with same `.Info/.Success/.Warn/.Error/.Debug` API.
- `src/errors/ErrorBoundary.tsx` — catches React render errors; never white-screens.
- `src/api/client.ts` — axios + bearer token + silent refresh on 401.
- `src/state/{auth,prefs}.store.ts` — zustand, persisted in AsyncStorage.
- `src/i18n/locales/{sv,en}.json` — every UI string. Swedish is the source of truth.
- `src/theme/colors.ts` + `ThemeProvider.tsx` — Västtrafik blue `#009DDC` palette, light + dark.

## packages/shared

zod DTOs reused between api + mobile.

## Where to start

1. `apps/api/src/server.ts` for the wiring.
2. `apps/api/src/matching/MatchingService.ts` for the core business rule (FIFO + 4-cap).
3. `apps/api/src/pricing/PricingEngine.ts` for the price formula.
4. `apps/mobile/app/(tabs)/home.tsx` for the user-facing market view.

# Source

Source path: `D:\GameProjects\vastshare` — pnpm monorepo, 3 workspaces.

## Backend — `apps/api/`

- `src/server.ts` — entrypoint. `buildServer()` is exported for tests / extension. Registers helmet, cors, cookie, sensible, errorHandler, then route modules.
- `src/config/env.ts` — zod-validated env loader. Fails fast on missing secrets. Exports `env` + `corsOrigins`.
- `src/logger/Logger.ts` — singleton `Logger` with `.Info / .Success / .Warn / .Error / .Debug`. JSON-line rotation to `logs/api-<day>.log`. Redacts `password / token / refreshToken / authorization / cookie / secret`.
- `src/errors/` — `AppError` (code, status, userMessageKey) + Fastify `errorHandler` hook. Never leaks internals.
- `src/db/prisma.ts` — singleton `PrismaClient`.
- `src/auth/` — register / login / refresh (rotation) / logout / delete-me. Argon2id + JWT.
- `src/middleware/authenticate.ts` — Bearer-JWT preHandler; attaches `req.user.id`.
- `src/users/` — `/me`, `/me/profile` (display name + phone + avatar base64), `/me/active-ticket`.
- `src/cards/` — `VtCard` CRUD scoped to the owner.
- `src/listings/`
  - `listings.service.ts` — `getMarketSnapshot()`, `createListing()`, `cancelListing()`, `getMyLoans()`.
  - `listings.routes.ts` — `/market`, `POST /listings`, `DELETE /listings/:id`, `POST /match`, `/my-loans`.
  - `active-ticket.service.ts` — `getActiveTicketFor(userId)`.
- `src/pricing/PricingEngine.ts` — pure function `priceFor({ config, tier, pendingCount }) → priceSek`. Unit-tested.
- `src/matching/MatchingService.ts` — interactive Prisma transaction with `FOR UPDATE SKIP LOCKED`, walks FIFO candidates, enforces 4-cap, creates `PaymentIntent` via `PaymentProvider`.
- `src/fees/feeConfig.ts` — `computeFee(amount)` → `{ amountSek, feeSek, payoutSek, feePct }`. `PLATFORM_FEE_PCT` env-driven.
- `src/payments/` — `PaymentProvider` interface + `FakeProvider` (active) + `SwishProvider` (stub) + `providerFactory.ts`.
- `src/vt/` — `vtClient.ts` (OAuth2 client-creds against PlaneraResa), `vt.routes.ts` (`/vt/locations`, `/vt/plan`), `vt.recommend.ts` (zone → CardType pure function).
- `src/health/health.routes.ts` — `/health`, `/ready`.
- `prisma/schema.prisma` — User · RefreshToken · AuditLog · VtCard · Listing · LenderRecipient · PaymentIntent · CardPriceConfig · VtRouteCache.
- `prisma/seed.ts` — upserts `CardPriceConfig` for all card types.
- `tests/{auth,pricing,fees,matching}.test.ts` — vitest, hits the real test Postgres.

## Mobile — `apps/mobile/`

### Routes (Expo Router)

- `app/_layout.tsx` — root providers (Theme, i18n, ErrorBoundary, Toast). Hydrates auth + prefs + resor stores.
- `app/index.tsx` — splash redirect to `/(auth)/login` or `/(tabs)/biljett`.
- `app/(auth)/` — login + register polished hero screens.
- `app/(tabs)/_layout.tsx` — 5-tab `<Tabs>` with custom `BottomTabBar`. AppHeader rendered above the tabs.
- `app/(tabs)/biljett.tsx` — active ticket hero card + countdown + lender + payment summary, or empty state.
- `app/(tabs)/lana-biljett.tsx` — market browse, filter chips, ListingRow cards (Standard + Snabbförsäljning side by side), ConfirmSheet → match → SuccessSheet → push to Biljett.
- `app/(tabs)/annonsera.tsx` — Mina kort + add-card collapsible + tier picker + payout preview.
- `app/(tabs)/resor.tsx` — Från / Till SearchFields + spring-animated swap button + departure/arrival segment + Sök resa + Favoriter + Senaste sökningar (max 6 FIFO).
- `app/(tabs)/profil/` — Stack with overview + installningar + kop-historik + salj-historik + support + om + delete.

### State (`src/state/`)

- `auth.store.ts` — zustand, persisted to `AsyncStorage` (`auth:v2`). Tracks user, accessToken, avatarBase64.
- `prefs.store.ts` — language + themeMode, persisted.
- `resor.store.ts` — search history (capped at 6 FIFO) + favourites (unbounded). Persisted.

### Design system (`src/design/`)

- `tokens.ts` — palette, spacing, radii, shadows, cardTypeColor.
- `typography.ts` — display / h1 / h2 / h3 / body / bodyMed / caption / label.
- `gradients.tsx` — `GradientHero` (linear gradient + SVG curve overlay) + `SoftPrimaryFade`.

### Component library (`src/components/`)

`AppHeader · BottomTabBar · Avatar · HeroPanel · Card · ListingRow · PriceTag · TierBadge · CardChip · StatChip · TimerCountdown · SearchField · SearchHistoryRow · SegmentControl · EmptyState · ConfirmSheet · SuccessSheet · SectionHeader · HintBanner · Button · TextField · Toast · Screen · LanguageSwitch · ErrorBoundary`.

### API client (`src/api/`)

- `client.ts` — axios with bearer JWT, 401 → silent refresh.
- `domain/{cards,match,vt,me}.ts` — typed wrappers per endpoint group.

### i18n (`src/i18n/`)

- `index.ts` — i18next init, syncs language from `prefs.store`.
- `locales/sv.json` — source of truth.
- `locales/en.json` — translation parity.

## Shared — `packages/shared/`

zod DTOs for auth + api error envelope. Imported by both api + mobile.

## Tooling

- `scripts/setup.mjs` — first-run bootstrap. Creates `.env`, generates JWT secrets, detects LAN IP and writes `EXPO_PUBLIC_API_URL`, starts Postgres, runs Prisma generate + db push, seeds. Idempotent quick-check mode for `predev`.

## Where to start

1. `apps/api/src/server.ts` — wiring.
2. `apps/api/src/matching/MatchingService.ts` — core business rule (FIFO + cap).
3. `apps/api/src/pricing/PricingEngine.ts` — price formula.
4. `apps/mobile/app/(tabs)/_layout.tsx` + `src/components/BottomTabBar.tsx` — nav structure.
5. `apps/mobile/src/design/tokens.ts` — visual language.

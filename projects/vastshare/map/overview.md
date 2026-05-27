# Overview

Project: **VästShare** — slug `vastshare`, source at `D:\GameProjects\vastshare`.

## Purpose

Modern Swedish-first (English toggle) mobile app for sharing Västtrafik travel cards ("låna kort"). Users lend out their period card while not using it; other users borrow it for a discount versus retail. Inspired by Tickital with a stricter FIFO + price-discovery model. The app does **not** sell Västtrafik tickets — it only brokers card sharing between strangers.

## Locked product rules

| # | Rule |
|---|---|
| 1 | Two listing tiers per card type: **Standard** (FIFO queue, higher price) and **Snabbförsäljning / Fast Sell** (FIFO queue, lower price floor). |
| 2 | Strict FIFO matching — buyers always take the oldest pending listing in the chosen tier. No price negotiation. |
| 3 | Per-lender monthly cap: **4 unique recipients**. Re-lending to the same buyer the same month doesn't count. Cap enforced at *match time* via `LenderRecipient` rows. |
| 4 | Dynamic pricing: ceiling/floor per card type, log-interpolated between `pendingCount` thresholds 10 and 1000. Snapshotted at listing creation. |
| 5 | Platform fee: env-driven `PLATFORM_FEE_PCT`, default **10%**, deducted from seller payout. Only realised on captured payments. |
| 6 | Fake-money now (`FakeProvider`), Swish later (`SwishProvider` stub). Switch via `PAYMENT_PROVIDER=fake|swish`. |
| 7 | Auth: email + Argon2id, JWT access (15m) + refresh (30d / 90d with "remember me"), rotation on refresh, soft-delete account. |
| 8 | Logger singleton with `Info / Success / Warn / Error / Debug` levels — backend (file + console) and mobile (console + in-memory ring). |
| 9 | Never hard-crash: backend `errorHandler` returns `{ code, userMessageKey }`; mobile `ErrorBoundary` + Toast surface user-friendly messages. |
| 10 | Strings in i18n only (`apps/mobile/src/i18n/locales/{sv,en}.json`). Default `sv`, toggleable. |

## High-level shape

- **Backend** — Fastify 5 + Prisma 6 + Postgres 16 (Docker), TypeScript. Entry `apps/api/src/server.ts`.
- **Mobile** — Expo SDK 52 + Expo Router (5-tab Swedish navbar) + NativeWind + zustand + i18next, TypeScript. Entry `apps/mobile/app/_layout.tsx`.
- **Shared** — zod DTOs in `packages/shared`.
- **Tooling** — pnpm workspaces, root `scripts/setup.mjs` for env / docker / migrations / seed / LAN-IP detection.

## Navigation map

Bottom tab order: **Biljett · LånaBiljett · Annonsera · Resor · Profil** (Annonsera is the elevated centre slot, Västtrafik-style). Top bar = wordmark + avatar (tap → Profil). Profil opens a stack with sub-pages: Inställningar, Köphistorik, Sälj Historik, Support & kontakt, Om appen, Radera konto.

## Current state (2026-05-26)

- All product rules wired and tested (`apps/api/tests/{auth,pricing,fees,matching}.test.ts`).
- Mobile UI completely rebuilt around the design system in `apps/mobile/src/design/` + custom component library in `apps/mobile/src/components/`.
- Avatar upload (`expo-image-picker` → base64 → `PATCH /me/profile`) works; persisted in Postgres `User.avatarBase64`.
- Phone preview via `pnpm dev:lan` (auto-detected LAN URL written to `.env` by `scripts/setup.mjs`) or `pnpm dev:tunnel`.
- Active ticket lookup: `GET /me/active-ticket` returns the user's currently-MATCHED listing.
- Resor (route planner) keeps up to 6 recent searches FIFO in AsyncStorage; favourites are unbounded and never evicted.

## Important links

- Source map: `map/source.md`
- Workflow / run commands: `map/workflow.md`
- Asset map: `map/assets.md`
- Project rules: `rules/project-rules.md`
- AI index: `.ai/index.json`
- System docs: `.ai/systems/`

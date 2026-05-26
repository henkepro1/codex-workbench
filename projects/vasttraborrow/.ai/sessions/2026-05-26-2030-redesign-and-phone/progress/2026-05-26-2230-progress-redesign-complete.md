# Progress: Redesign complete

**Created**: 2026-05-26T22:30:00+02:00

## What landed

### Audit (Phase A)
Confirmed all 17 locked product rules are wired with file paths — see `map/overview.md`. No backend logic changes needed.

### Visual identity (Phase B)
- `apps/mobile/src/design/tokens.ts` — palette, spacing (4-pt grid), radii, shadows, gradient stops, `cardTypeColor` map.
- `apps/mobile/src/design/typography.ts` — 8 named text styles.
- `apps/mobile/src/design/gradients.tsx` — `GradientHero` (LinearGradient + decorative SVG curves) + `SoftPrimaryFade`.
- `apps/mobile/tailwind.config.js` extended with the full `vt.*` palette + `vt-night / nightSoft / accentFast / border / borderDark`.
- `apps/mobile/src/theme/colors.ts` re-exports tokens.

### Component library (~17 new files)
`AppHeader · BottomTabBar · Avatar · HeroPanel · Card · ListingRow · PriceTag · TierBadge · CardChip · StatChip · TimerCountdown · SearchField · SearchHistoryRow · SegmentControl · EmptyState · ConfirmSheet · SuccessSheet · SectionHeader · HintBanner`. All under `apps/mobile/src/components/`.

### Navigation (Phase C)
`apps/mobile/app/(tabs)/_layout.tsx` rebuilt: renders `<AppHeader>` above a `<Tabs tabBar={<BottomTabBar/>}>` with 5 Swedish-named screens. Old tab files (`home`, `my-card`, `my-loans`, `profile`, `route-planner`) deleted.

### Screens (Phase D)
- `biljett.tsx` — active ticket hero (Gradient + CardChip + TimerCountdown + payment summary) or `EmptyState` linking to LånaBiljett.
- `lana-biljett.tsx` — `HeroPanel`, horizontal filter chips, per-CardType `Card` with side-by-side Standard / Snabbförsäljning `ListingRow`s, `ConfirmSheet` → match → `SuccessSheet` → push to Biljett.
- `annonsera.tsx` — `Mina kort` list with tier picker (`SegmentControl`) and live payout preview, add-card collapsible.
- `resor.tsx` — `HeroPanel`, Från/Till `SearchField`s with circular swap button, depart/arrive `SegmentControl`, search button, `Favoriter` + `Senaste sökningar` rows (max 6 FIFO).
- `profil/_layout.tsx` + 7 sub-pages (`index`, `installningar`, `kop-historik`, `salj-historik`, `support`, `om`, `delete`).
- `(auth)/login.tsx` + `register.tsx` rebuilt with `GradientHero` + tagline.

### Backend (Phase E)
- `User.avatarBase64 String?` added to Prisma schema; applied via `prisma db push`.
- `UpdateProfileBodySchema` extended with `avatarBase64` (zod, 220 KB cap).
- `users.service.ts::updateProfile` accepts the field with explicit size guard.
- New route `GET /me/active-ticket` powered by `apps/api/src/listings/active-ticket.service.ts`.

### Resor history (Phase D continued)
`apps/mobile/src/state/resor.store.ts` — zustand, persisted to `AsyncStorage` (`resor:history:v1` + `resor:favorites:v1`). History capped at 6 FIFO; favourites unbounded and never evicted.

### Mobile-phone access (Phase F)
- Added `"dev:lan"` and `"dev:tunnel"` to root `package.json`.
- `scripts/setup.mjs` now auto-detects the LAN IPv4 and writes `EXPO_PUBLIC_API_URL=http://<lan-ip>:4000` plus appends the matching `http://<lan-ip>:8081` to `CORS_ORIGINS`.
- README updated with the "Open on your phone" section.

### Template propagation
All generic pieces mirrored into `D:\GameProjects\_template-app\` (design system, generic components, auth.store, tailwind config, theme colors, setup.mjs LAN logic, dev:lan / dev:tunnel scripts, README section).

### i18n
`apps/mobile/src/i18n/locales/{sv,en}.json` regenerated end-to-end with all new strings — tab labels, screen copy, Resor history, profile sub-pages, FAQ, error messages.

## What the user still needs to do

- Reload <http://localhost:8081> to see the new UI on the web target.
- Open Expo Go on phone and either scan the QR from the `pnpm dev:lan` terminal or punch in `exp://192.168.1.131:8081` manually.

## Open follow-ups (not done)

- Dark-mode pass — most surfaces are light-only-tested.
- Real branded artwork (logo SVG, illustrations).
- Map search in Resor (deferred per the plan).
- Push notifications (toggle in Inställningar is a placeholder).
- Swish provider — `SwishProvider.ts` is still a stub.

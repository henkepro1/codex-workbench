# Design System

## Overview
Code-defined visual language for the mobile app. Three layers: design tokens (palette, spacing, radii, shadows, typography) in `src/design/`, a Tailwind config that mirrors the tokens for class-name styling (NativeWind), and a custom component library in `src/components/` built on those tokens. No raster photography — gradients + SVG curves + Lucide icons only.

## How It Works

### Tokens (`src/design/tokens.ts`)
- `palette` — `primary` (#009DDC), `primaryDeep`, `primarySoft`, `ink`, `inkSoft`, `paper`, `paperSoft`, `night`, `nightSoft`, `accentFast`, `ok`, `warn`, `danger`, `border`, `borderDark`.
- `heroGradient` / `heroGradientFast` / `heroGradientDanger` — 2-stop linear stops.
- `spacing` — 4-pt grid: `xs sm md lg xl xxl hero`.
- `radii` — `sm md lg xl pill`.
- `shadows.card` + `shadows.hero` — RN shadow + Android elevation pairs.
- `cardTypeColor` — per-`CardType` accent for `CardChip`.

### Typography (`src/design/typography.ts`)
Eight named styles: `display / h1 / h2 / h3 / body / bodyMed / caption / label`. `label` is uppercase with 1-px tracking.

### Gradients (`src/design/gradients.tsx`)
- `GradientHero` — full-bleed `LinearGradient` + an SVG curve overlay (`react-native-svg`) for organic shape.
- `SoftPrimaryFade` — vertical fade for behind-the-Card backdrops.

### Tailwind / NativeWind (`tailwind.config.js`)
Re-declares the palette under the `vt.*` namespace so `text-vt-ink`, `bg-vt-paperSoft`, `border-vt-primary` work in JSX className. The `borderRadius."2xl"` token aligns to `radii.xl=20`.

### Components (`src/components/`)
Primitives:
- `Avatar` — circular, image-or-initials fallback. Sizes 32/40/56/72.
- `Card` — elevated container with optional left accent stripe.
- `HintBanner` — dismissible (AsyncStorage-persisted) tip line.
- `EmptyState` — circle-tinted icon + title/body/cta.
- `StatChip` / `CardChip` / `TierBadge` — pills with tone variants.
- `PriceTag` — kr-suffixed big number + retail percentage caption.
- `TimerCountdown` — ticking mm:ss / hh:mm:ss display.
- `SearchField` — icon-left input.
- `SegmentControl` — generic pill-row toggle.
- `TextField` / `Button` / `Toast` / `Screen` — pre-existing primitives.

Composites:
- `AppHeader` — top wordmark + tappable avatar (avatar → /profil).
- `BottomTabBar` — 5-tab Swedish nav with elevated centre slot for Annonsera; renders for the (tabs) layout.
- `HeroPanel` — gradient banner with title + subtitle.
- `ListingRow` — tier badge + queue count + PriceTag + CTA.
- `SearchHistoryRow` — recent trip with star toggle.
- `ConfirmSheet` / `SuccessSheet` — bottom-sheet modals.
- `SectionHeader` — back-arrow + title for stack sub-pages.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/mobile/src/design/tokens.ts` | Single source of design truth |
| `apps/mobile/src/design/typography.ts` | Text styles |
| `apps/mobile/src/design/gradients.tsx` | Gradient hero + decorative SVG |
| `apps/mobile/tailwind.config.js` | NativeWind palette mirror |
| `apps/mobile/src/theme/colors.ts` | Re-exports + light/dark theme tokens |
| `apps/mobile/src/theme/ThemeProvider.tsx` | System / light / dark resolver |
| `apps/mobile/src/components/*` | The component library |

## Integration Points
- Every screen imports from `@/design/tokens` + `@/design/typography` + `@/components/*`.
- `usePrefsStore.themeMode` (system / light / dark) drives `ThemeProvider`. Dark mode is wired through tokens but most screens currently default to light surfaces; rerun a pass once you have feedback.
- Lucide icons via `lucide-react-native` are the only icon family — 20px in tab bar, 22px in headers, 18px inline.

## Known issues / future work
- Dark mode contrast hasn't been audited — most surfaces and ink-soft text need a re-check on a real dark screen.
- Component library lacks: Toast position config, Snackbar undo, Skeleton loaders, BottomSheet drag handle gestures.
- No Storybook / showcase route for component visual testing.
- No animated transitions between Login ↔ Register (still a hard navigation).
- Real branded artwork (logo SVG, illustrations) is deferred — see [[../map/assets.md]].

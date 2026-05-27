# Mobile Navigation

## Overview
File-based routing via Expo Router 4. Two route groups: `(auth)` for unauthenticated, `(tabs)` for the authenticated 5-tab shell. The (tabs) layout renders `AppHeader` (wordmark + avatar) above a `<Tabs>` whose `tabBar` is the custom Swedish `BottomTabBar`. Profil is a nested Stack with 6 sub-pages.

## How It Works

### Top-level (`app/_layout.tsx`)
Wraps the entire app in providers: `GestureHandlerRootView` → `SafeAreaProvider` → `ThemeProvider` → `ToastProvider` → `ErrorBoundary` → `<Stack>` with three children:
- `index` (splash redirect)
- `(auth)` group
- `(tabs)` group

On mount, hydrates `auth.store` + `prefs.store`.

### Splash redirect (`app/index.tsx`)
Reads `useAuthStore.hydrated + user`. While unhydrated, renders a centered `ActivityIndicator`. Once hydrated: redirect to `/(tabs)/biljett` if logged in, else `/(auth)/login`.

### Auth group (`app/(auth)/`)
- `_layout.tsx` — `<Stack>` with `headerShown: false`.
- `login.tsx` — hero panel + email/password + remember-me + LanguageSwitch. On success → `router.replace("/(tabs)/biljett")`.
- `register.tsx` — display name + email + password. Same redirect.

### Tabs group (`app/(tabs)/_layout.tsx`)
Renders an `<AppHeader>` above a `<Tabs tabBar={<BottomTabBar />}>` with 5 screens in this order: `biljett`, `lana-biljett`, `annonsera`, `resor`, `profil`. Auth guard: `if (hydrated && !user) router.replace("/(auth)/login")`. Also hydrates `resor.store` if needed.

### BottomTabBar (`src/components/BottomTabBar.tsx`)
Custom rendering — receives `BottomTabBarProps` from `@react-navigation/bottom-tabs`. Renders:
- 4 standard slots (Biljett, LånaBiljett, Resor, Profil) with Lucide icon + Swedish label + active underline pill.
- 1 elevated centre slot (`Annonsera`) — circular `PlusCircle` button raised 16px above the bar with shadow.

Active state highlights via `palette.primary`; inactive uses `palette.inkSoft`.

### Profil sub-stack (`app/(tabs)/profil/`)
- `_layout.tsx` — `<Stack headerShown:false>`.
- `index.tsx` — Profile overview: avatar + name + monthly counter + 6 tiles.
- `installningar.tsx` — settings (avatar pick, display name, language, theme, notifications placeholder, delete-account link).
- `kop-historik.tsx` — purchases as buyer.
- `salj-historik.tsx` — sales as lender.
- `support.tsx` — mail + GitHub + FAQ accordion.
- `om.tsx` — about / version / credits.
- `delete.tsx` — destructive delete-account confirmation.

Each sub-page renders a `<SectionHeader title back-arrow>` since the global `AppHeader` always shows the wordmark.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/mobile/app/_layout.tsx` | Root providers + initial hydration |
| `apps/mobile/app/index.tsx` | Splash redirect |
| `apps/mobile/app/(auth)/_layout.tsx` · `login.tsx` · `register.tsx` | Auth screens |
| `apps/mobile/app/(tabs)/_layout.tsx` | Tabs shell + AppHeader |
| `apps/mobile/app/(tabs)/biljett.tsx` · `lana-biljett.tsx` · `annonsera.tsx` · `resor.tsx` | Root tab screens |
| `apps/mobile/app/(tabs)/profil/_layout.tsx` + 7 children | Profil sub-stack |
| `apps/mobile/src/components/BottomTabBar.tsx` | Custom 5-slot tab bar |
| `apps/mobile/src/components/AppHeader.tsx` | Top bar (wordmark + avatar) |
| `apps/mobile/src/components/SectionHeader.tsx` | Sub-page back-header |

## Integration Points
- The avatar in `AppHeader` reads `useAuthStore.avatarBase64` — updating it via the Installningar screen reflects immediately in the top-right across every tab.
- Deep links: LånaBiljett accepts `?filter=<CardType>` for pre-filter (used by Resor's "Hitta utlånare" CTA).
- Auth gate: removing the user from the store (logout, delete-me) auto-redirects via the `(tabs)/_layout.tsx` effect.

## Known issues / future work
- No tab-bar haptics or scroll-to-top on re-tapping the same tab.
- Web target: `BottomTabBar` renders but the active-tab top pill could use a smoother animation.
- No deep-link config in `app.json` (`scheme: vastshare`) wired to specific routes yet.
- Tab labels are hardcoded in `BottomTabBar` rather than from i18n — refactor to use `useTranslation()` if you want labels to change with the language toggle.

# Progress — emulator wired, runtime polyfills, dep graph deduped

**Date:** 2026-05-27 14:11 CET
**Status:** App boots in Android emulator; auth/network requires API + adb-reverse 4000 (pending user)

## Root causes diagnosed

### 1. `import.meta is not supported in Hermes` (Metro bundle error)
- Origin: `zustand@4.5.5/esm/index.mjs` uses `import.meta.env.MODE` for a dev warning.
- Hermes (the JS engine) doesn't implement `import.meta`. Babel must rewrite it.
- **Fix:** added `unstable_transformImportMeta: true` to `babel-preset-expo` options in [apps/mobile/babel.config.js](D:\GameProjects\vastshare\apps\mobile\babel.config.js).
- Alternative (not used): upgrade to `zustand@5` which drops the `import.meta` reference entirely.

### 2. `getDevServer is not a function (it is Object)` (runtime crash)
- Investigation: `.pnpm/` directory had **three copies** of `react-native@0.81.5` (paired with different `@babel/core` peer contexts), **two copies** of `@babel/core` (7.25.2 from inside metro@0.83.3, 7.29.7 direct devDep), **three copies** of `metro` (0.83.3, 0.83.7, 0.84.4), **three copies** of `metro-runtime`, plus a stray `react-native@0.76.0` dragged in by jest-expo → old expo-router@4 → @expo/metro-runtime@4 peer cascade.
- Symptom in code: `setUpReactDevTools.js` does `require('./Devtools/getDevServer').default` — when the runtime loads `getDevServer` from one RN copy but the module-id table was populated from a different copy, the CJS interop returns the module exports object instead of the `.default` function.
- **Fix:** nuked `pnpm-lock.yaml` + all `node_modules/`, ran `pnpm install` fresh. Resolved to:
  - `react-native`: 1 copy
  - `@babel/core`: 1 copy
  - `metro`: 3 copies (harmless — only one bundles at a time, others sit unused on disk)
- User explicitly rejected the `pnpm.overrides` approach; nuke-and-reinstall was chosen as the cleanest canonical path.

### 3. `j` doesn't open DevTools
- `pnpm dev:lan` from the root uses `pnpm run --parallel --filter=./apps/* dev:lan`. The parallel runner swallows interactive keystrokes — they never reach Expo CLI.
- **Fix:** run mobile dev server alone via a separate terminal: `cd apps/mobile && pnpm exec expo start --lan`. Now `j`/`r`/`a`/`m` work.

### 4. Splash screen forever after `a` opened emulator
- Emulator can't reach Metro at `192.168.1.131:8081` (the host's LAN IP) reliably from its virtual network.
- **Fix:** `adb reverse tcp:8081 tcp:8081` forwards emulator-side `localhost:8081` to host `localhost:8081`. Expo Go then downloads the bundle.

### 5. i18next plural warning on first app load
- Hermes lacks `Intl.PluralRules` on Android. i18next falls back to compatibilityJSON v3 and complains.
- **Fix:** `pnpm --filter mobile add intl-pluralrules`; added `import 'intl-pluralrules';` as the very first line of [apps/mobile/src/i18n/index.ts](D:\GameProjects\vastshare\apps\mobile\src\i18n\index.ts) so it polyfills before i18next initializes.

### 6. `react-native-svg@15.12.1` imports Node `buffer`
- Metro blocks Node-stdlib imports from JS bundles. `react-native-svg`'s new `fetchData.ts` (added in 15.12.x for remote SVG support) does `import { Buffer } from 'buffer'`.
- **Fix:** `pnpm --filter mobile add buffer` (userland polyfill), wired into [apps/mobile/metro.config.js](D:\GameProjects\vastshare\apps\mobile\metro.config.js) via `config.resolver.extraNodeModules.buffer = require.resolve('buffer/')`.

### 7. SafeAreaView deprecation warning
- Not in user code — every user-code import of `SafeAreaView` already comes from `react-native-safe-area-context`. Library-internal (likely expo-router or react-navigation transitive).
- **Fix:** `LogBox.ignoreLogs(['SafeAreaView has been deprecated'])` added at the top of [apps/mobile/app/_layout.tsx](D:\GameProjects\vastshare\apps\mobile\app\_layout.tsx). Strictly noise suppression — the library itself will pick up its own fix on its next release.

### 8. `Network Error /auth/login`
- API isn't running (`localhost:4000` refuses connections).
- Even when API is up, emulator's `localhost` is the emulator itself.
- **Pending user action:**
  1. `cd D:\GameProjects\vastshare && pnpm --filter api dev:lan` (start API in a separate terminal)
  2. `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:4000 tcp:4000`

## System setup performed

- **Android Studio** installed via `winget install Google.AndroidStudio` (v2025.3.4.7, ~1.3 GB).
- SDK installed via Android Studio's first-launch wizard (Standard mode) → `%LOCALAPPDATA%\Android\Sdk`.
- Env vars set at User scope:
  - `ANDROID_HOME = C:\Users\henke\AppData\Local\Android\Sdk`
  - `PATH += %ANDROID_HOME%\platform-tools; %ANDROID_HOME%\emulator`
- AVD created via Virtual Device Manager: **Pixel 8 + API 34 (UpsideDownCake), Google APIs, x86_64**.

## Gotchas to remember

- **VS Code caches env at process launch.** Setting User PATH from a script doesn't reach already-open VS Code terminals. Must restart VS Code (whole app, not just terminal) for `adb` to resolve by name. Workaround until restart: use full path `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"`.
- **`adb reverse` survives only until emulator/adb-server is killed.** Each fresh emulator boot needs `adb reverse tcp:8081 tcp:8081` (and 4000 for the API) re-run. Worth scripting if this becomes friction.
- **`expo start --lan` vs Android emulator:** LAN mode advertises the host's WiFi IP. Emulator NAT may or may not route to it. `adb reverse` is the reliable bridge. For physical phones on WiFi, LAN IP works without adb.
- **Splash hang ≠ crash.** Expo Go displays the app's configured splash while fetching the bundle. Forever-splash usually means bundle never downloaded (network/port reachability), not a JS error.
- **`pnpm run --parallel` swallows keystrokes.** For interactive Expo CLI controls, run Metro alone in its own terminal.

## Open follow-ups

- Run the API + `adb reverse 4000` to unblock `/auth/login`.
- Consider whether `jest-expo`'s old expo-router@4 peer (which still resolves but uselessly) is worth purging via a focused `pnpm.overrides`; current fresh-install state hasn't reintroduced the issue but transitive peer pickiness could resurface.
- Peer-dep warnings persist for `react@19` vs `^18` ranges in `react-test-renderer`, `lucide-react-native`, `zustand`'s `use-sync-external-store`. Working fine today but watch for hook/render bugs.

# Input — mobile bundle failures + emulator setup request

**Date:** 2026-05-27 ~12:00 CET
**Source:** Live terminal sessions on Windows 10, repo at `D:\GameProjects\vastshare`

## What the user reported (in order)

1. `pnpm dev:lan` succeeded for API + setup, but mobile Metro bundle failed:
   `SyntaxError: ... import.meta is not supported in Hermes. Enable the polyfill unstable_transformImportMeta in babel-preset-expo to use this syntax.` — origin: `zustand@4.5.5/esm/index.mjs`.
2. After enabling that flag, the device showed a red-box runtime crash:
   `TypeError: getDevServer is not a function (it is Object)` — even after Metro `--clear`.
3. User requested a clean, scalable fix — **not** a `pnpm.overrides` workaround.
4. After the fix, app loaded but a console error appeared on phone: i18next plural resolver warning re: missing `Intl.PluralRules`.
5. User asked for an Android emulator path because reading errors off a physical phone is painful. Pressing `j` in the `pnpm dev:lan` terminal did nothing.
6. After emulator setup, splash stayed forever — bundle wasn't reaching Expo Go on the emulator.
7. After bundle loaded: SafeAreaView deprecation warning + `/auth/login` network error.

## Constraints / preferences confirmed in-session

- No workarounds — find the actual root cause.
- Direct, single-step instructions; no hedging "screenshot if confusing" prose for predictable installer flows.
- Solo dev; mostly Unity background; mobile/web is newer territory for them.

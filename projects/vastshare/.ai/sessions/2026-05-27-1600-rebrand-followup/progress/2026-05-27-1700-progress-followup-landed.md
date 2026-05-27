# Progress — v2.1 follow-up landed

**Date:** 2026-05-27 17:00 CET
**Status:** Typecheck clean; awaiting on-device confirmation.

## Changes

### 1. Wordmark — V replaces leading 'v'
- File: [apps/mobile/src/components/Wordmark.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\Wordmark.tsx).
- Text content changed from `västshare` → `ästshare`. The SVG V mark now occupies the leading-letter slot.
- The Svg viewBox cropped to `5 4 14 16` so the V's stroke fills its layout box vertically without padding. Height set to ~1.85 × the font-size (~caps height for Space Grotesk Medium), width is a ~0.55 ratio of the height (matches the stroke geometry). Margin between mark and text is `-2` so the kerning reads as one word.
- The Svg gradient + accent dot still come from `palette.primaryGlow` → `palette.primary`, identical to v2.0.

### 2. Auth screens — design fidelity
- Files: [login.tsx](D:\GameProjects\vastshare\apps\mobile\app\(auth)\login.tsx), [register.tsx](D:\GameProjects\vastshare\apps\mobile\app\(auth)\register.tsx).
- **Removed** the static `// svenska · english` mono footer on both. It was decoration with no behaviour.
- **Removed** the outer `<Pressable>` wrapping the "Kom ihåg mig" `<Switch>` + label row. The Switch component is its own tap target; the wrapping Pressable's `onPress` was double-toggling when the user's finger landed in the label area.
- Container changed from `<View>` → `<KeyboardAvoidingView>` was already done in v2.0; kept.
- The footer's `{t("mono.languageFooter")}` key in [sv.json](D:\GameProjects\vastshare\apps\mobile\src\i18n\locales\sv.json) + [en.json](D:\GameProjects\vastshare\apps\mobile\src\i18n\locales\en.json) is now unused but left in place for now — easy to remove later if it never gets resurrected.

### 3. Settings language picker — dropdown sheet
- New file: [apps/mobile/src/components/LanguagePicker.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\LanguagePicker.tsx).
- Exports a `<LanguagePicker>` component that renders:
  - A row trigger: `// språk` mono label on the left + current language native name (e.g. `Svenska`) on the right with a chevron.
  - On tap: opens a bottom sheet (same `Modal` + `expo-blur` + `surface` + `primaryEdge` top-border shell as `ConfirmSheet`/`SuccessSheet`).
  - Sheet body: `// välj språk` mono header + a list of available languages. Each row has the native name + lowercase English meta line + a `Check` icon on the active one. Tapping a row calls `usePrefsStore.setLanguage(code)`, which i18next already subscribes to, then closes the sheet.
- Language list lives in one `const LANGUAGES` array at the top of the file. Adding a third language is one entry + one entry in the `Language` union in [@/state/prefs.store](D:\GameProjects\vastshare\apps\mobile\src\state\prefs.store.ts).
- [installningar.tsx](D:\GameProjects\vastshare\apps\mobile\app\(tabs)\profil\installningar.tsx) — replaced the old `<Card><Text /><LanguageSwitch /></Card>` block with just `<Card><LanguagePicker /></Card>`. The picker's row owns its own label so the wrapper Card is bare.
- Deleted [LanguageSwitch.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\LanguageSwitch.tsx). Nothing else referenced it.

### 4. AvatarMenu popover
- New file: [apps/mobile/src/components/AvatarMenu.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\AvatarMenu.tsx).
- Exports `<AvatarMenu open onClose>`. Uses a transparent `Modal` with a `Pressable` backdrop for outside-tap dismiss. The menu card is absolutely positioned at `top: insets.top + 50 + 6, right: 12` — directly under the AppHeader, anchored to the avatar's column.
- Menu card: `surface2` bg, 1px `primaryEdge` border, 10px radius, indigo halo shadow. 6 navigation rows (Profil / Inställningar / Köphistorik / Sälj historik / Support / Om appen) + a 1px divider + Logga ut row in danger tone.
- Each row uses `bodyMedium` 14px text + an inline Lucide icon at 16px stroke 1.5. Logout reuses the same `api.post("/auth/logout") → clearSession → router.replace("/(auth)/login")` sequence as the profile-tab logout row.
- [AppHeader.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\AppHeader.tsx) — added `const [menuOpen, setMenuOpen] = useState(false)`. The avatar's `onPress` now toggles `setMenuOpen(true)` instead of routing directly. The `<AvatarMenu>` is rendered as a sibling.

### 5. Profile tab page — no code change
- [profil/index.tsx](D:\GameProjects\vastshare\apps\mobile\app\(tabs)\profil\index.tsx) already lists 6 rows (settings, purchases, sales, support, about, logout). Verified [`profile.tiles.*`](D:\GameProjects\vastshare\apps\mobile\src\i18n\locales\sv.json) i18n keys present in both locales. No render bug expected; the user's screenshot simply didn't reach this screen due to the login network error.

## Verification

- `pnpm --filter mobile typecheck` clean.
- Lint script still broken (no eslint installed; pre-existing, not from this session).
- On-device verification deferred to the user: `pnpm exec expo start --lan --clear`, then `adb reverse tcp:8081 tcp:8081` + `adb reverse tcp:4000 tcp:4000` (the `/auth/login` network error from the previous screenshot is the adb forward dropping after emulator restart — not a code bug, but needs re-running every time the emulator boots).

## Gotchas to remember

- **Wordmark sizing** — the V mark is height-stretched to optically match the leading-letter height. If the font-size baseline ever shifts (e.g. swapping Space Grotesk Medium for a different weight), the `1.85` ratio and the `-2` left margin will need re-tuning. Eyeball it side-by-side with the design reference image.
- **AvatarMenu anchoring** — the `topAnchor` math assumes the AppHeader is exactly 50px tall plus the safe-area inset. If the header height ever changes, update `+ 50 + 6` to match.
- **Bottom sheets share visual language** — ConfirmSheet, SuccessSheet, LanguagePicker all inline the same modal-with-blur-backdrop pattern. If you build a 4th sheet, consider extracting `<BottomSheet>` as a primitive — the duplication is just verging on warranting it.
- **Switch double-toggle gotcha** — wrapping a `<Switch>` in a `<Pressable>` whose `onPress` also toggles the same state is a footgun. The label is fine inside a Pressable, but the Switch itself doesn't need one. Lesson logged.

## Open follow-ups

- The `mono.languageFooter` i18n key is now orphaned. Remove next time we touch locales.
- The user mentioned "but more may come in future.(perhaps))" for languages — `LanguagePicker`'s structure is already extensible.
- If/when we get production logo artwork, the wordmark SVG and the generated `assets/icon.png` etc. all swap out at once.

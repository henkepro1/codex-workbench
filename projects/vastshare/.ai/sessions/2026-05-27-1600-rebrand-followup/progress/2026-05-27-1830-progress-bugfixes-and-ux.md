# Progress — post-1700 bugfixes + UX changes

**Date:** 2026-05-27 18:30 CET
**Status:** Typecheck clean; user has confirmed Button + Switch render correctly on emulator.

After the initial v2.1 polish (1700 note) landed, the user tested on the emulator and surfaced a chain of fidelity + UX issues. Each was resolved in-place; this note records them so the trail isn't lost.

## Bugs fixed

### 1. Button rendering as plain text (no indigo background)
- Symptom: the "Logga in" / "Skapa konto" buttons rendered as just bold text on top of the form card — no fill, no border, no shadow. Two earlier attempted fixes (`alignSelf: "stretch"`, then explicit `width: "100%"`) didn't take.
- Root cause: nativewind v4's `cssInterop` wraps `Pressable` to support `className`. The wrap was silently dropping the function-form `style={({ pressed }) => …}` in some bundle states. We'd already had to patch this same library this session (for the SafeAreaView deprecation), so it was a known suspect.
- Fix in [Button.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\Button.tsx): visual styling moved to an outer **`<View>`** (plain RN, not wrapped by cssInterop). The inner `<Pressable>` is now a transparent tap surface that fills the View. Style is a single static object, not a function. Pressed-state opacity is tracked with `useState` and applied to the outer View. Bulletproof.

### 2. "Kom ihåg mig" switch didn't match the design
- Symptom: native RN `<Switch>` rendered as a platform-default pill. The design uses a custom 36×20 rounded-square (border-radius 4) with a 14×14 white thumb.
- Fix: new [BrandSwitch.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\BrandSwitch.tsx). 36×20 squircle with the brand's surface3/primary fill + border-edge rim per state; 14×14 white thumb at `left: 2 ↔ 18`. Replaced RN `<Switch>` in [login.tsx](D:\GameProjects\vastshare\apps\mobile\app\(auth)\login.tsx) and [installningar.tsx](D:\GameProjects\vastshare\apps\mobile\app\(tabs)\profil\installningar.tsx).

### 3. Switch row double-toggled
- Symptom: tapping the "Kom ihåg mig" text area toggled twice (once via the Switch's own gesture, once via the wrapping `<Pressable>`'s `onPress`).
- Fix: removed the outer `<Pressable>` wrapping the Switch + label. Now a plain `<View>` row. Tap target is the Switch itself.

## UX changes from this session

### 4. API host auto-derived from Metro — no more `adb reverse tcp:4000 tcp:4000`
- User: _"why i need to run this awkward adb reverse thing all the time?"_
- Root cause: `adb reverse` is transient (lives in adb server memory; gone after emulator restart). Expo CLI auto-reverses port 8081 (Metro), but nothing was reversing port 4000 (API).
- Fix in [src/api/client.ts](D:\GameProjects\vastshare\apps\mobile\src\api\client.ts): added a `resolveApiUrl()` resolver. Order: `EXPO_PUBLIC_API_URL` env → `expoConfig.extra.apiUrl` config → derive from `Constants.expoConfig.hostUri` (Metro's LAN IP) → `localhost`. In dev, the emulator + physical phone both reach the API at the same LAN IP Metro is serving from, no port forwarding needed. API must be binding to `0.0.0.0` (the default for Node/Fastify) for this to work.

### 5. Register → login redirect (no auto-login)
- User: _"if i register it will automatically log me in afterwards. We don't want that. Register (success) => take me to login screen and also autofill the 'Email' in (but not password)."_
- Fix in [register.tsx](D:\GameProjects\vastshare\apps\mobile\app\(auth)\register.tsx): dropped `setSession`. After a successful POST, toast `auth.registerSuccess` and `router.replace({ pathname: "/(auth)/login", params: { email } })`. [login.tsx](D:\GameProjects\vastshare\apps\mobile\app\(auth)\login.tsx) now reads `useLocalSearchParams<{ email?: string }>` and uses it as the initial value for the email state.
- New i18n key `auth.registerSuccess` in both [sv.json](D:\GameProjects\vastshare\apps\mobile\src\i18n\locales\sv.json) (`Konto skapat — logga in nedan.`) and [en.json](D:\GameProjects\vastshare\apps\mobile\src\i18n\locales\en.json) (`Account created — sign in below.`).

### 6. Mono `// ` prefix → `- `
- User wanted the brand's signature `// label` eyebrow swapped for `- label` everywhere.
- Fix: [MonoLabel.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\MonoLabel.tsx) default prefix changed from `"// "` to `"- "`. [HeroPanel.tsx](D:\GameProjects\vastshare\apps\mobile\src\components\HeroPanel.tsx) was manually prepending `// `; rewrote to pass eyebrow content through MonoLabel (default prefix handles it) with a regex strip for any incoming `// ` legacy callers. Affects every label across all screens — `- EMAIL`, `- LÖSENORD`, `- MARKET`, `- LEND`, `- TRIP PLANNER`, etc.

### 7. Generic "Something isn't right" toast on Zod validation
- User reported registering with `henkepro@hotmail.com1` returned that toast with no clue about what was wrong.
- Diagnosis: Zod's `z.string().email()` regex requires TLDs of letters only (`[a-zA-Z]{2,}`); `com1` is correctly rejected as invalid. The backend already includes Zod's `meta.issues` with `path` + `message` per field, but [handleApiError.ts](D:\GameProjects\vastshare\apps\mobile\src\lib\handleApiError.ts) was discarding it and always returning `errors.validation`.
- Fix: when `code === "validation"` and `meta.issues` has a leading-path field, map it to `errors.validation_<field>`. Mapped fields today: `email`, `password`, `displayName`, `phoneNumber`, `nickname`. Unknown fields fall back to the generic key. New keys added to both locale files (e.g. `validation_email`: _"That email doesn't look right. Check the spelling and top-level domain."_).

## Verification

- `pnpm --filter mobile typecheck` clean after every change.
- Button + Switch confirmed visually correct in the user's screenshot.
- Other changes pending the user's next reload.

## New patterns to remember

- **Avoid `style={fn}` on nativewind-wrapped components.** When `cssInterop(react_native_1.Foo, ...)` has wrapped a primitive, the function-form `style` prop becomes a liability. Either use static-object `style`, or wrap the visual in a plain `<View>` and put the Pressable/Touchable inside as a transparent surface. We've now had this bite us twice — first the SafeAreaView deprecation, now the Button background.
- **Don't rely on `adb reverse` for app-internal services.** Anything the bundle calls during dev (API, auxiliary servers) should be discoverable from `Constants.expoConfig.hostUri`. Hard-coding `localhost` only works on the iOS simulator; on Android emulator and physical phones it breaks until someone runs adb commands.
- **Pass Zod `meta.issues` through to the UI.** A field-level validation failure is the cheapest, most actionable error message we can show — the backend already produces it; just don't throw it away in error mapping.
- **Don't auto-login after register if there's any chance you'll want a confirmation step later** (email verification, ToS, etc.). Bouncing through login keeps that door open without re-engineering the flow.

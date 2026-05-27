# Input — v2 rebrand follow-up feedback after first emulator test

**Date:** 2026-05-27 ~16:00 CET
**Source:** Live emulator session after the v2.0 rebrand landed (see [2026-05-27-1411 session](../../2026-05-27-1411-emulator-and-runtime-fixes/)).

## What the user reported

Five things, in order:

1. **Wordmark visual bug** — the `<Wordmark>` renders `[V SVG mark] + "västshare"` text, which reads as "V västshare" — a double-V. The user wants the V mark to *replace* the leading `v` so the lockup reads as one stylised word. Their exact words: _"instead of 'västshare' it should be the 'loggo (looks like a v) + ästshare' so basically västshare but the loggo instead of the v (of course perfectly aligned so it doesn't look too weird)."_

2. **Login + Register design isn't 100% to the Claude Design reference.** The user wants pixel-identical: _"I asked for an identical fix. Not 90% or 80% or 99%. A 100% IDENTICAL style."_ Specific issues — the static `// svenska · english` footer is non-interactive cruft (user wants it gone), and the `<Switch>` row was wrapped in an outer `<Pressable>` that double-toggles when tapped.

3. **Language switch should move to settings as a dropdown.** _"inside settings somewhere a dropdown list of the available languages (in this case its just swe / english but more may come in future)."_ The current pill-style toggle on the auth screens is being removed entirely.

4. **AppHeader avatar should open a dropdown menu.** _"and at the topright (should be an icon of your uploaded profile otherwise generic one) its also technically profile but there we can see a dropdown and perhaps see the 'settings' etc."_ Today tapping the avatar just navigates to the profile tab — the user wants a popover with quick shortcuts to all sub-pages.

5. **The user thought features were missing** — om/support/settings/historik. Investigation showed those routes still exist and the profile bottom-tab's `index.tsx` still iterates a 6-row list to them. The user's screenshot didn't show them because they were blocked on the auth login network error (couldn't get past login). The avatar-menu fix surfaces these routes from anywhere in the app, which is what they really wanted.

## Constraints / preferences confirmed in-session

- The design reference is the spec — don't relitigate, just match it.
- One-shot delivery — land all fixes in this pass.
- Network error on `/auth/login` was the recurring `adb reverse tcp:4000 tcp:4000` issue; not a code problem.
- User explicitly does *not* want light mode, so the previous theme picker stays removed.

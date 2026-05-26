# VT Route Planner Integration

## Overview
Proxies Västtrafik's PlaneraResa API (`ext-api.vasttrafik.se`) for two operations: location autocomplete and journey planning. Translates the journey's tariff zones into a recommended `CardType` so the user knows which card type to look for in [[listings]]. Cached briefly in the `VtRouteCache` table to keep API quota low.

## How It Works

### OAuth2 (`vtClient.ts::getToken`)
Client-credentials grant — base64(`VT_CLIENT_ID:VT_CLIENT_SECRET`) Basic auth → POST `/token`. Caches the resulting access token with a 30-second safety margin before its `expires_in`. Both env vars are optional; if missing, `vtClient` returns mocked responses so dev works without API credentials.

### `searchLocations(query)`
GET `/pr/v4/locations/by-text?q=…&limit=8` with bearer. Returns the raw VT response.

### `planJourney({ originName, destinationName, departAt? })`
GET `/pr/v4/journeys?originName=…&destinationName=…&dateTime=…` with bearer. Returns the raw VT response.

### Zone → CardType (`vt.recommend.ts`)
Pure helpers:
- `zonesFromVtResponse(payload)` → `Set<"A"|"B"|"C"|"REGIONAL">` by walking `tariffZones[].shortName`.
- `recommendCardType(zones)`:
  - `REGIONAL` → `REGIONAL_DAY`
  - else `C` → `ABC`
  - else `B` → `AB`
  - else → `A`

### Route + cache (`vt.routes.ts`)
`POST /vt/plan`:
1. Compute `cacheKey = sha256(origin|destination|departAt)`.
2. If `VtRouteCache` row exists and `fetchedAt + ttlSeconds*1000 > now` → return cached.
3. Else call `planJourney`, compute `recommendedCardType`, upsert cache with `ttlSeconds=300`.

`GET /vt/locations?q=...` is uncached (fast endpoint).

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/vt/vtClient.ts` | OAuth2 + HTTP wrappers |
| `apps/api/src/vt/vt.routes.ts` | Fastify routes + cache logic |
| `apps/api/src/vt/vt.recommend.ts` | pure zone → CardType + zone parser |
| `apps/api/prisma/schema.prisma` | `VtRouteCache` model |
| `apps/mobile/app/(tabs)/resor.tsx` | UI: Från / Till / swap / time filter / Sök |
| `apps/mobile/src/state/resor.store.ts` | local history + favorites in AsyncStorage |
| `apps/mobile/src/api/domain/vt.ts` | typed client |

## Integration Points
- Result navigates to `/(tabs)/lana-biljett` with `?filter=<CardType>` so the LånaBiljett tab pre-filters to the recommended type.
- Search history (6 FIFO) + favorites (unbounded) are stored client-side in `AsyncStorage` keys `resor:history:v1` and `resor:favorites:v1`.

## Known issues / future work
- Map search is deferred — Resor UI doesn't yet have map pickers, only text fields.
- No "use current location" — the placeholder pill on focus exists but isn't wired to `expo-location` yet.
- `tariffZones` parsing is heuristic; the VT response shape may surface zones differently in some journeys. Verify against a sampled response before going live.
- No retry/backoff on transient VT API failures; relies on the user re-tapping Sök.

# Pricing

## Overview
Two pure functions decide every price + fee:
- `PricingEngine.priceFor` — returns a Snapshotted price for a fresh listing, log-interpolated between a ceiling and a floor based on `pendingCount` (how many other listings exist in the same card+tier queue).
- `computeFee` — returns `{ amountSek, feeSek, payoutSek, feePct }` rounded.

The lender does **not** set a price. They pick a tier (Standard or Snabbförsäljning) and the engine sets the price at listing time. The price is snapshotted on the row so a later queue shift doesn't retroactively change someone's promised price.

## How It Works

### `priceFor({ config, tier, pendingCount })`
- `ceiling = tier === "STANDARD" ? config.baseLoanSek : config.fastTopSek`
- `floor   = tier === "STANDARD" ? config.floorLoanSek : config.fastFloorSek`
- `pendingCount <= 10`   → `price = ceiling`
- `pendingCount >= 1000` → `price = floor`
- Otherwise → `t = (log10(pendingCount) - 1) / (3 - 1)` and `price = round(ceiling - t * (ceiling - floor))`.
- Clamped to `[floor, ceiling]` defensively.

Why log-interp instead of linear: keeps prices stable in the 10–100 range and drops sharply in the 100–1000 range. Matches the intuition that "many listings → real oversupply" should compress price hard.

Example (ABC, Standard, ceiling 100, floor 60):
- pendingCount =   0 → 100
- pendingCount = 100 → 80 (log10=2, t=0.5)
- pendingCount = 1000 → 60

### `computeFee(amountSek, overridePct?)`
- `pct = overridePct ?? PLATFORM_FEE_PCT` (env default `10`).
- `feeSek = round(amountSek * pct / 100)`.
- `payoutSek = amountSek - feeSek`.

Banker's-rounding is **not** used; plain `Math.round` so 7.5 → 8, 12.5 → 13. Documented in tests.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/pricing/PricingEngine.ts` | `priceFor`, `PRICING_THRESHOLDS` |
| `apps/api/src/fees/feeConfig.ts` | `PLATFORM_FEE_PCT` env, `computeFee` |
| `apps/api/prisma/seed.ts` | seeds `CardPriceConfig` per `CardType` |
| `apps/api/src/listings/listings.service.ts::createListing` | snapshots price at listing creation |
| `apps/api/src/matching/MatchingService.ts` | applies the fee at match capture |
| `apps/api/tests/pricing.test.ts` | boundary + interp tests |
| `apps/api/tests/fees.test.ts` | rounding + override tests |
| `apps/mobile/src/lib/fee.ts` | client-side mirror for live preview |

## Integration Points
- `CardPriceConfig` row per `CardType` is the only DB-side knob — admin can edit per-type ceilings/floors there without code changes.
- `pendingCount` is computed by `listings.service.ts` at the moment of listing creation. The query is `Listing.count({ cardType, tier, status: PENDING })`.
- The mobile-side `computeFee` is for previews only — backend `MatchingService` is the authoritative source on capture.

## Known issues / future work
- Prices don't account for time-to-expiry of the card (a 1-day-left card should be cheaper). Add a multiplier in v2.
- No price floor adjustments based on retail price drift — `CardPriceConfig.fullRetailSek` is currently informational only on the client.
- Banker's rounding would be slightly fairer for sellers (8 vs 7 at 7.5); revisit if needed.

# Listings & Market

## Overview
Card lending listings live in the `Listing` table with status `PENDING / MATCHED / COMPLETED / CANCELLED / EXPIRED`. The "market" is a denormalised snapshot per card type × tier showing the live price (via [[pricing]]) and queue depth.

## How It Works

### Create (`listings.service.ts::createListing`)
1. Resolve the `VtCard` and confirm the requesting user owns it.
2. Reject if the card is expired (`validUntil <= now`).
3. Reject if the card already has a `PENDING` listing (one open listing per card).
4. Fetch `CardPriceConfig` for the card type. 500-error if missing.
5. Count `PENDING` listings of the same `cardType, tier`. Call `priceFor` to snapshot the price.
6. `prisma.listing.create` with `status=PENDING`.
7. Log `[INFO] Listing created id=… priceSek=… tier=…`.

### Market snapshot (`getMarketSnapshot`)
For every seeded `CardPriceConfig`, runs `Listing.count` twice (Standard + FAST_SELL) and computes the current `priceSek` via `priceFor`. Returns an array of `{ cardType, standard: {priceSek, pendingCount}, fastSell: {priceSek, pendingCount} }`.

### My loans (`getMyLoans`)
Returns two lists (50 most-recent each) of the user's listings as lender and as buyer, plus `monthlyUniqueRecipients` (count of `LenderRecipient` rows this `YYYY-MM`) and the fixed cap (4). Includes the related `card`, `payment`, and the counterparty user.

### Cancel
Only the listing's lender can cancel. Only allowed while `PENDING`. Sets `status=CANCELLED`. No fee accrued.

### Active ticket
`active-ticket.service.ts::getActiveTicketFor(userId)` returns the user's most-recently-matched listing where `card.validUntil > now`. Used by the Biljett tab's hero card + countdown.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/listings/listings.service.ts` | core CRUD + market snapshot + my-loans |
| `apps/api/src/listings/listings.routes.ts` | `/market`, `POST /listings`, `DELETE /listings/:id`, `POST /match`, `/my-loans` |
| `apps/api/src/listings/active-ticket.service.ts` | active-ticket lookup |
| `apps/api/src/cards/cards.routes.ts` | underlying `VtCard` CRUD |
| `apps/mobile/app/(tabs)/lana-biljett.tsx` | market browse UI |
| `apps/mobile/app/(tabs)/annonsera.tsx` | listing creation UI |
| `apps/mobile/app/(tabs)/biljett.tsx` | active-ticket UI |
| `apps/mobile/src/api/domain/cards.ts` · `match.ts` · `me.ts` | typed client wrappers |

## Integration Points
- Drives [[matching]] (consumer of `PENDING` rows).
- Snapshot price uses [[pricing]].
- Render layer uses `CardChip`, `TierBadge`, `PriceTag`, `ListingRow` from [[design-system]].

## Known issues / future work
- No background expiry job for `card.validUntil < now` → orphan `PENDING` rows accumulate. Add a `node-cron` style sweep before going live.
- The market snapshot does N+1 `count`s — fine at low scale, becomes slow at thousands of listings. Replace with a single grouped `groupBy` query when needed.
- No pagination on `getMyLoans`. Hard limit 50 is fine for v1.

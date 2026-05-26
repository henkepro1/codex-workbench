# Matching

## Overview
Strict FIFO buyer → listing matcher with a per-lender monthly cap of 4 unique recipients. Runs inside a Postgres `SERIALIZABLE` transaction using `FOR UPDATE SKIP LOCKED` so concurrent buyers can't both claim the same head-of-queue listing. Skips self-listings and capped-lender listings, then captures the payment via the active `PaymentProvider`.

## How It Works

### Entry point: `matchBuyer({ buyerId, cardType, tier })`
1. Open `prisma.$transaction` with `{ isolationLevel: "Serializable" }`.
2. `SELECT * FROM "Listing" WHERE cardType=$1 AND tier=$2 AND status='PENDING' ORDER BY createdAt ASC LIMIT 50 FOR UPDATE SKIP LOCKED;`
3. Walk candidates in order. For each:
   - If `listing.lenderId == buyerId` → skip (no self-lending).
   - Compute current `ym = YYYY-MM`. Check `LenderRecipient.findUnique({ lenderId, recipientId=buyerId, periodYm=ym })`.
   - If a row exists → existing pair, **allow** regardless of cap.
   - Else, `count distinct recipientId WHERE lenderId AND periodYm=ym`. If `>= 4` → skip this listing.
4. First non-skipped candidate wins. `getPaymentProvider().createIntent({...})`. Compute `feeSek` via `computeFee(priceSek)` (see [[pricing]] for the formula).
5. Update the listing (`status=COMPLETED` if FakeProvider captured immediately, else `MATCHED`). Create the `PaymentIntent` row. Upsert `LenderRecipient` if this is a new pair.
6. Commit.

### Return shape
- `{ ok: true, listingId, lenderId, cardType, tier, priceSek, feeSek, payoutSek, paymentRef }` — success.
- `{ ok: false, reason: "queue_empty" | "all_capped" }` — no match.

`reason: "all_capped"` is set when the walk saw at least one candidate but all skipped due to the 4-cap.

### Concurrency invariant
`FOR UPDATE SKIP LOCKED` plus SERIALIZABLE isolation guarantees two concurrent `matchBuyer` calls for the same card/tier can't both claim the same listing. Tested via `Promise.all` of two buyers against a 1-listing queue (only one returns `ok: true`).

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/matching/MatchingService.ts` | `matchBuyer`, `periodYm` helper |
| `apps/api/src/listings/listings.routes.ts` | `POST /match` route wrapper |
| `apps/api/src/payments/providerFactory.ts` | resolves the active `PaymentProvider` |
| `apps/api/src/fees/feeConfig.ts` | fee math, called inside the match |
| `apps/api/tests/matching.test.ts` | FIFO ordering, 4-cap, self-skip, concurrent-claim |
| `apps/api/prisma/schema.prisma` | `Listing`, `LenderRecipient`, `PaymentIntent` |

## Integration Points
- Triggered by `POST /match` (mobile: `apps/mobile/src/api/domain/match.ts::matchBuyer`).
- Returns are passed to `apps/mobile/app/(tabs)/lana-biljett.tsx` which renders the SuccessSheet on `ok` and toasts on `!ok`.
- `LenderRecipient` index `(lenderId, periodYm)` keeps the count cheap.
- Read by Profil screen: `GET /my-loans` returns `monthlyUniqueRecipients` for the counter.

## Known issues / future work
- The Prisma `SERIALIZABLE` isolation hint plus `FOR UPDATE SKIP LOCKED` via `$queryRawUnsafe` is correct in practice but a serialisation conflict could throw — wrap callers with a retry once for robustness.
- 4-cap is hardcoded; pull from a config table or env (`MONTHLY_RECIPIENT_CAP`) when going live.
- No expiry on `Listing.PENDING` — add a sweeper for listings whose `card.validUntil < now`.

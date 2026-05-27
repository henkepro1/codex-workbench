# Payments

## Overview
`PaymentProvider` is a 3-method interface. The active provider is resolved at module init by `providerFactory.ts` from `PAYMENT_PROVIDER=fake|swish`. `FakeProvider` writes virtual ledger entries and treats every intent as immediately captured — good for dev + demo. `SwishProvider` is a stub with an explicit TODO list; flipping the env var will surface `NotImplementedError` until the stub is filled in.

## How It Works

### Interface (`PaymentProvider.ts`)
```ts
interface PaymentProvider {
  readonly name: "fake" | "swish";
  createIntent(input: CreateIntentInput): Promise<CreatedIntent>;
  capture(providerRef: string): Promise<{ status: "captured"; providerRef: string }>;
  refund(providerRef: string): Promise<void>;
}
```

`CreateIntentInput` includes `listingId`, `buyerId`, `lenderId`, and the resolved `{ amountSek, feeSek, payoutSek }` from [[pricing]].

### `FakeProvider` (active)
- `createIntent` generates `fake_<6 random hex bytes>` as `providerRef` and returns `status: "captured"` immediately.
- `capture` is a no-op echo.
- `refund` logs.

### `SwishProvider` (stub)
Throws `AppError({code:"internal", status:501, userMessageKey:"errors.internal", meta:{reason:"swish_not_implemented"}})` from every method. The class doc lists the 7-step plan to wire the real Swish Merchant API.

### Factory caching
`getPaymentProvider()` caches the instance the first time it's called. `resetPaymentProviderCache()` exists for tests.

## Key Classes & Files

| File | Role |
|---|---|
| `apps/api/src/payments/PaymentProvider.ts` | interface + input/output types |
| `apps/api/src/payments/FakeProvider.ts` | current implementation |
| `apps/api/src/payments/SwishProvider.ts` | stub + TODO list for real Swish |
| `apps/api/src/payments/providerFactory.ts` | env-driven resolver + cache |
| `apps/api/src/matching/MatchingService.ts` | only caller of `createIntent` today |
| `apps/api/prisma/schema.prisma` | `PaymentIntent` model |

## Integration Points
- Called from `MatchingService.matchBuyer` (see [[matching]]).
- Logs via [[logger-error]]; no `console.log`.
- Env: `PAYMENT_PROVIDER` (default `fake`).
- `PaymentIntent` table is the audit trail. Index on `(buyerId)` + `(lenderId)` supports the Profil > Köp/Sälj-historik views.

## Known issues / future work
- No retry / idempotency keys yet. Swish needs idempotency for `createIntent`.
- No webhook receiver — the real Swish flow needs `POST /webhooks/swish/payment` to flip `MATCHED → COMPLETED`.
- No payout reconciliation table; lender balance is implicit from `PaymentIntent.payoutSek` rows.
- Currency is hardcoded `SEK`. Multi-currency would touch this + `PricingEngine`.

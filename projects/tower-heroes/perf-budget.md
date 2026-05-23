# Tower Heroes Performance Budget

Use this as the project-specific performance target sheet. Update with measured numbers as profiling data becomes available.

## Current Defaults

- Assume 1000+ active gameplay entities for scalable systems.
- Avoid per-frame allocations in hot paths.
- Respect existing pooling, prewarm, tick, and update-budget systems.
- Do not add broad scene searches or uncached component lookups in gameplay loops.

## Measured Budgets

- Frame time budget: TBD.
- Script update budget: TBD.
- GC allocation budget per frame: 0 bytes in hot paths unless explicitly justified.
- Enemy/tower/projectile scale targets: TBD.
- Draw call or batching targets: TBD.

## Notes

Replace TBD values with measured project numbers when profiling data exists.

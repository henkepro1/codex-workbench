# Crowd Simulation

## Overview
Prevents enemies from stacking or clipping through each other by maintaining a spatial bucket grid of all live enemies and providing neighbor-query and priority-resolution services. Each enemy queries this system every tick to obtain nearby neighbors, compute separation/steering forces, and determine who yields in contested passages. Connector (ramp) traffic is additionally policed by dedicated traversal utilities.

## How It Works

**Spatial bucketing — `EnemyCrowdService`.** On `EnsureBucketStorageConfigured`, the service derives a grid of `DenseBucket` arrays from `GridManager.Origin`, `GridManager.GridSize`, and `bucketSize` (= `SubcellSize * BucketSubcellSpan`, effectively two subcells). Buckets are keyed by a flat index `(bucketY * bucketGridWidth) + bucketX` and are stored per-level in `bucketsByLevel`. An 8-cell padding ring (`BucketStoragePadding`) ensures enemies slightly outside the authored grid bounds never out-range the array.

**Lifecycle.** When `EnemyUnit.Initialize` completes, it calls `EnemyCrowdService.Register(this)`, which places the enemy into the correct `DenseBucket` based on `CachedWorldPosition` and `CurrentSurfaceLevel`. Buckets use swap-back (`RemoveAtSwapBack`) on removal so there are no gaps. Each affected swap updates the `IndexInBucket` field in `TrackedEnemyBucketState` for the moved enemy. On death or goal-reach, `Unregister` removes the enemy from its bucket and decrements the per-level count.

**Updating position.** During each `EnemyUnit.TickSimulation`, after applying displacement, `UpdateRegistration(this)` is called. If the enemy moved into a different bucket or a different level, the old bucket entry is swapped out and a new one is added. The `bucketOccupancyVersion` counter is not incremented here (it is a neighbor-query-cache invalidation mechanism); instead the `neighborQueryCache` is invalidated by version comparison when the bucket layout changes.

**Neighbor collection — `CollectNeighbors`.** Given an `EnemyUnit` requester and a `queryRadius`, the method resolves the requester's current bucket coordinates, computes a `bucketRadius`, and retrieves or builds a `EnemyCrowdNeighborQueryCacheEntry` listing the local bucket key set. It then AABB-filters each candidate bucket against the circular query radius (`DoesBucketAabbOverlapQueryCircle`) and performs per-enemy distance checks within passing buckets. Only enemies on the same level as the requester are considered. If the result buffer fills (`saturated = true`), `EnemyUnit` doubles its `neighborBuffer` and retries. Buffer saturation is also recorded via `GameplayMetricsTrace.RecordNeighborBufferSaturation`.

**Tower targeting — `CollectAttackableTargetsInRange`.** Used by `TowerTargetingModule` (not enemy movement). Searches all levels within a circle, skipping dead (`IsDead`) enemies. This is the same bucket scan, without the level restriction.

**Priority resolution — `EnemyCrowdPriorityService`.** Tracks alive counts per `WaveSequenceNumber`. On each new wave number appearing or disappearing, `RebuildOlderWaveStepCache` sorts the active wave numbers and assigns each an "older wave step" count (how many newer waves currently have live enemies). Higher step = older wave = higher priority.

`FillPairPriorityAdvantagesForRegisteredNeighbors` fills a `float[]` output buffer with one priority value per neighbor, in the range `[-1, 1]`. The formula is:
- Base priority = `(moverOlderWaveSteps - neighborOlderWaveSteps) * OlderWavePriorityStepWeight`.
- Same-wave bonus = distance-lead toward goal, normalized to `SameWaveFrontPriorityDistanceCells` and scaled by `SameWaveFrontPriorityMaxBonus`.

These priority values are stored in `EnemyUnit.neighborPriorityBuffer` and used to scale body radii: a mover with negative priority against a neighbor shrinks its interaction radius (yielding more), while positive priority keeps full radius.

`CompareTraversalRightOfWay` provides a definitive -1/0/1 ordering used when two enemies contest a narrow passage. Tie-breaking falls through to `RemainingRouteDistanceToGoal` then alphabetical `RuntimeId` comparison, giving a deterministic stable sort.

**Connector corridor displacement — `EnemyConnectorTransitionTraversalUtility`.** For ramp segments, `FindLargestAllowedDisplacement` binary-searches the largest fraction of the requested displacement that keeps the enemy inside a `corridorHalfWidth` band around the segment line and makes positive forward progress. Critically, it projects onto the lane _line_ (not the clamped parametric segment) so an enemy that has entered a new ramp subcell at its boundary edge but not yet reached the guide waypoint is not falsely rejected. `EnemyConnectorCorridorDisplacementUtility` provides a related helper for same-level ramp movement.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `EnemyCrowdService` | `_Project/Scripts/Waves/EnemyCrowdService.cs` | Singleton spatial bucket grid; owns Register/Unregister/UpdateRegistration/CollectNeighbors/CollectAttackableTargetsInRange |
| `EnemyCrowdPriorityService` | `_Project/Scripts/Waves/EnemyCrowdPriorityService.cs` | Singleton priority resolver; tracks alive counts per wave, fills neighbor priority buffers |
| `DenseBucket` | `_Project/Scripts/Waves/DenseBucket.cs` | Compact unordered array with swap-back removal; one instance per occupied (level, bucketKey) pair |
| `EnemyCrowdNeighborQueryCacheEntry` | `_Project/Scripts/Waves/EnemyCrowdNeighborQueryCacheEntry.cs` | Cached bucket-key list for a given (level, bucketX, bucketY, bucketRadius) tuple |
| `EnemyCrowdNeighborQueryCacheKey` | `_Project/Scripts/Waves/EnemyCrowdNeighborQueryCacheKey.cs` | Struct key for the neighbor query cache |
| `EnemyConnectorTransitionTraversalUtility` | `_Project/Scripts/Waves/EnemyConnectorTransitionTraversalUtility.cs` | Static; binary-search for largest lane-corridor-conforming displacement on ramp transitions |
| `EnemyConnectorCorridorDisplacementUtility` | `_Project/Scripts/Waves/EnemyConnectorCorridorDisplacementUtility.cs` | Same-level connector corridor displacement helper |
| `EnemyNavigationSettings` | `_Project/Scripts/Waves/EnemyNavigationSettings.cs` | ScriptableObject; all crowd-related tuning (`CrowdRepulsionWeight`, `NeighborQueryRadiusCells`, `OlderWavePriorityStepWeight`, etc.) |
| `GameplayMetricsTrace` | `_Project/Scripts/Waves/GameplayMetricsTrace.cs` | Per-tick metric sink; records neighbor buffer saturation, hard-trap events, repath counts |

## Integration Points

- **Called by:** `EnemyUnit.TickSimulation` calls `EnemyCrowdService.CollectNeighbors` and `EnemyCrowdService.UpdateRegistration` every frame per enemy. `TowerTargetingModule` calls `EnemyCrowdService.CollectAttackableTargetsInRange` to find attack targets.
- **Calls into:** `GridManager` (subcell size, origin, grid size for bucket layout). `GameplayMetricsTrace` (saturation and slow-frame events).
- **Shared state / data contracts:** `EnemyUnit.CachedWorldPosition` and `EnemyUnit.CurrentSurfaceLevel` are the inputs to all bucket operations. `EnemyUnit.WaveSequenceNumber` and `EnemyUnit.RemainingRouteDistanceToGoal` are inputs to priority resolution. `EnemyCombatTarget.IsDead` is checked by `CollectAttackableTargetsInRange` to filter dead enemies from tower targeting results.

## Debug Guide

**Enemies visibly overlapping / passing through each other.**
- Check whether `EnemyCrowdService.UpdateRegistration` is being called after each move. If `tickCrowdRegistrationSkippedSameBucket` is consistently true (same bucket both before and after move), the bucket resolution is correct but spatial separation forces may be too weak — adjust `CrowdRepulsionWeight` and `CrowdSideBiasWeight` in `EnemyNavigationSettings`.
- Verify `NeighborQueryRadiusCells` is large enough relative to `BodyHalfExtentFraction`. If two enemies are far enough apart to fall outside each other's query radius, no separation force is generated.

**Neighbor buffer saturation warnings in logs.**
- `GameplayMetricsTrace.RecordNeighborBufferSaturation` fires when the buffer doubles. This is expected during heavy congestion and auto-resolves. If the buffer is growing unboundedly, a chokepoint may be causing extreme local density — investigate corridor width vs. enemy body radius.

**Older-wave enemies not yielding to newer waves.**
- Confirm `WaveSequenceNumber` is being set correctly at spawn (it must be positive). Check `EnemyCrowdPriorityService.aliveCountsByWaveSequenceNumber` in the debugger — if a wave number is missing, `RebuildOlderWaveStepCache` was not triggered. Any Register/Unregister with a new wave number triggers a rebuild.

**Tower not targeting enemies.**
- `CollectAttackableTargetsInRange` uses a flat 2D position (x/y only), so towers on level 0 will see enemies on all levels. Enemies are excluded only if `CombatTarget.IsDead`. If a tower reports zero targets when enemies are visible, check that enemies are registered in `EnemyCrowdService` (verify `isCrowdRegistered` flag on `EnemyUnit`) and that `GridManager.GridSize` is already non-zero at the time of first registration.

**Bucket out-of-range errors.**
- Error: "EnemyCrowdService resolved out-of-range bucket X/Y". An enemy has moved outside the padded bucket grid, which should only happen if it teleported or if the grid origin changed while enemies were registered. The latter throws a separate error "detected a runtime layout change while enemies are still registered".

## Known Issues / Gotchas

- The neighbor query cache (`neighborQueryCache`) is keyed on `(level, bucketX, bucketY, bucketRadius)` and invalidated by `bucketOccupancyVersion`. However `bucketOccupancyVersion` is only used for this cache and is never actually incremented during normal gameplay bucket updates — the cache entries rebuild themselves by comparing `OccupancyVersion == bucketOccupancyVersion`. This means the cache is effectively always valid once built for a given bucket position, which is intentional (bucket geometry does not change at runtime). If you add dynamic grid resizing, this would need to be incremented.
- `DenseBucket` swap-back removal updates the moved enemy's `IndexInBucket` in `TrackedEnemyBucketState`. If you add any code that holds a stale index reference outside of `TrackedEnemyBucketState`, it will silently read the wrong enemy.
- The crowd system only considers enemies on the same level as the requester (`CollectNeighbors` gates on `requesterLevel`). Enemies on different elevation levels do not influence each other's steering even if their world positions coincide visually.

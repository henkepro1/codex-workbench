# Enemy Movement

## Overview
Drives per-enemy movement simulation each combat tick. Every live `EnemyUnit` follows a precomputed route made of world-space waypoints, applies velocity with crowd-steering and obstacle-repulsion influences, enforces body-clearance constraints on ramp traversal, and recovers autonomously from stall conditions. The system is the main per-frame cost center for enemy gameplay.

## How It Works

**Tick entry.** `EnemyMovementSimulationService` subscribes to `GameplaySimulationService.CombatTicked`. On each tick it iterates `registeredEnemies` and calls `enemyUnit.TickSimulation(deltaTime)` on each. The list uses swap-back removal for O(1) unregister. `stallRefreshDedupKeysThisTick` is cleared at tick start to prevent multiple enemies at the same location from each triggering an independent stall repath in the same frame.

**Per-enemy tick flow inside `EnemyUnit.TickSimulation`.** Steps execute in order every frame:

1. **Surface-level refresh.** `RefreshCurrentSurfaceLevelFromSegmentProgress` maps the current path-segment to its elevation level. `currentSurfaceLevel` is used for all subsequent navigation queries.

2. **Topology change detection.** If `EnemyPathService.TopologyVersion` has changed (a tower was placed or removed), the enemy checks whether it needs a new route via `ShouldRefreshPathForTopologyChange`. If yes it calls `RefreshPath(false)` and runs a blocked-overlap resolution pass.

3. **Blocked-overlap resolution.** `ResolveBlockedSubcellOverlaps` runs when `requiresBlockedOverlapResolution` is set. It tries to nudge the enemy to the nearest clear subcell so subsequent movement can proceed.

4. **Path progress advance.** `AdvancePathProgress` iterates `nextPathPointIndex` forward for any waypoints already reached. `HasReachedRoutePathPoint` is the reach test; for ramp (connector) segments it uses subcell membership and corridor checks rather than simple Euclidean distance. On reaching the last waypoint, `GameManager.HandleEnemyReachedGoal` fires and the object is destroyed.

5. **Displacement construction.** `GetSegmentForwardDirection` gives the heading toward the next waypoint. `CollectNeighborsForTick` queries `EnemyCrowdService` for nearby enemies. `FilterRelevantNeighborsForTick` trims the list to actually relevant candidates. `CacheNeighborPairPriorities` calls `EnemyCrowdPriorityService.FillPairPriorityAdvantagesForRegisteredNeighbors` to stamp a priority float on each neighbor pair. `BuildRequestedDisplacement` blends forward direction, crowd-steering (`CalculateCrowdSteering`), and obstacle-repulsion into a single vector.

6. **Displacement constraint.** `ResolveBestDisplacement` binary-searches the largest fraction of the requested displacement that passes body-clearance checks. It tries the primary direction, then a preferred-slip direction, then an alternate-slip direction, finally a binary-search fallback. For ramp segments, `FindLargestConnectorRouteableBodyClearDisplacement` runs interpolated subcell checks along the path. For flat terrain, `FindLargestTraversableDisplacementOnCurrentLevel` uses a cached blocked-subcell sample.

7. **Position application.** `TranslateWorldPosition` applies the final displacement. After moving, `EnemyCrowdService.UpdateRegistration` repositions the enemy in the spatial bucket grid. `CanSkipPostMoveBlockedOverlapResolution` decides whether to re-check overlap after the move.

8. **Stall recovery.** `UpdateStallRecovery` tracks `stalledSeconds`. Meaningful progress (path-point advance, route distance, net world distance, or single-tick distance) resets the counter. Without progress, the system escalates: body-radius compression starts at `BodyCompressionStallStartSeconds`, the side-bias sign flips at `SideSwapStallDelaySeconds`, the hard-trap mode activates at `HardTrapEnterSeconds` when surrounded by `HardTrapNeighborThreshold` or more neighbors, and a full `RefreshPath` fires after `StallRepathDelaySeconds`. Repath deduplication (`TrySuppressRedundantStallRecoveryPathRefresh`) prevents redundant refreshes using `EnemyRouteValidationKey` and `EnemyStallRecoveryBlockedSampleSignature`.

9. **Diagnostics.** `GameplayMetricsTrace` records per-frame profiling (stage timings, neighbor counts, displacement decisions). `RampTraversalTrace` records detailed ramp-traversal events; `RampTraversalTrace.Drain()` flushes buffered records at the end of each tick.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `EnemyMovementSimulationService` | `_Project/Scripts/Waves/EnemyMovementSimulationService.cs` | Singleton tick driver; owns the registered-enemies list; calls `TickSimulation` on each enemy |
| `EnemyUnit` (movement partial) | `_Project/Scripts/Waves/EnemyUnitMovement.cs` | Main per-enemy tick; displacement construction, constraint, application, path advance |
| `EnemyUnit` (stall partial) | `_Project/Scripts/Waves/EnemyUnitStallRecovery.cs` | Stall detection, hard-trap escalation, repath dedup, `RefreshPath` calls |
| `EnemyUnit` (base partial) | `_Project/Scripts/Waves/EnemyUnit.cs` | Init, registration, state serialization, deactivation |
| `EnemyNavigationSettings` | `_Project/Scripts/Waves/EnemyNavigationSettings.cs` | ScriptableObject; all per-enemy navigation tuning constants |
| `EnemyConnectorTransitionTraversalUtility` | `_Project/Scripts/Waves/EnemyConnectorTransitionTraversalUtility.cs` | Static helper; binary-search for largest corridor-conforming displacement on ramp segments |
| `EnemyUnitCrossLevelTraversal` | `_Project/Scripts/Waves/EnemyUnitCrossLevelTraversal.cs` | Ramp cross-level transition logic |
| `EnemyUnitRoutePlanning` | `_Project/Scripts/Waves/EnemyUnitRoutePlanning.cs` | Route plan construction and rebuild helpers |
| `EnemyUnitSpatialState` | `_Project/Scripts/Waves/EnemyUnitSpatialState.cs` | Helpers for resolving subcell coordinates and level from world position |
| `EnemyNavigationDiagnostics` | `_Project/Scripts/Waves/EnemyNavigationDiagnostics.cs` | Navigation issue logging helpers |
| `RampTraversalTrace` | `_Project/Scripts/Waves/RampTraversalTrace.cs` | Per-frame ramp event ring buffer; drained at end of each tick |
| `EnemyStallRecoveryBlockedSampleSignature` | `_Project/Scripts/Waves/EnemyStallRecoveryBlockedSampleSignature.cs` | Value type used to dedup stall repaths by blocked-subcell pattern |
| `EnemyStallRefreshTickDedupKey` | `_Project/Scripts/Waves/EnemyStallRefreshTickDedupKey.cs` | Value type used to prevent same-tick duplicate repath across enemies in same position |

## Integration Points

- **Called by:** `GameplaySimulationService.CombatTicked` event — fires once per combat frame with `deltaTime`.
- **Calls into:** `EnemyPathService` (route plan, topology version, blocked subcell queries), `ElevationMapService` (connector ownership, level world-position mapping), `EnemyCrowdService` (neighbor queries, bucket registration updates), `EnemyCrowdPriorityService` (pair priority computation), `GridManager` (subcell/cell sizes, origin), `GameplayMetricsTrace`, `RampTraversalTrace`.
- **Shared state / data contracts:** `EnemyRoutePlan` — contains `WorldPoints[]`, `SubcellPath[]`, `WorldPointLevels[]`, `WorldPointStartSubcellIndices[]`, `NextCheckpointIndexByWorldPoint[]`. This is the central data contract between path planning and movement execution. `EnemyUnit.CachedWorldPosition` is read by `EnemyCrowdService` and `EnemyCrowdPriorityService` every tick.

## Debug Guide

**Enemy not moving / stuck in place.**
- Check `stalledSeconds` and `isHardTrapActive` via `GameplayMetricsTrace` slow-frame events or `RampTraversalTrace.stall_recovery_decision` records.
- If `tickZeroDisplacementAfterConstraints` is consistently true, check for blocked subcells at the enemy's position on its `currentSurfaceLevel` — a placed tower may be overlapping the enemy.
- If `tickStallRecoveryAction` cycles between `stall_refresh_suppressed` and `stall_refresh`, the repath returns the same route. Check `EnemyRouteValidationKey` values to confirm.

**Enemy snapping / teleporting near ramps.**
- Enable `RampTraversalTrace` focused recording for the affected enemy's `runtimeId`. Look for `path_point_progress` records with reason `connector_arrival_outside_next_corridor` or `cross_level_endpoint_not_yet_reached` — these indicate the enemy advanced a path point before physically being inside the next corridor.
- Check `EnemyConnectorTransitionTraversalUtility.FindLargestAllowedDisplacement` — a degenerate corridor segment (start == end) throws at runtime.

**Enemy ignoring obstacles after topology change.**
- Look for `RecordTopologyRefresh` and `RecordPathRefresh` in `GameplayMetricsTrace`. If topology changes are not triggering a refresh, verify `ShouldRefreshPathForTopologyChange` is returning true — it gates on `DoesLatestTopologyChangeAffectSubcellNeighborhood` and `IsLatestTopologyChangeRelevantToRoute`.

**Performance — too many repath calls.**
- `GameplayMetricsTrace.RecordRepathAttempt` and `RecordSuppressedStallRecoveryRefresh` track repath volume. High `RecordRepathAttempt` with low displacement usually means enemies are crowded on a connector and cycling through stall recovery. Tuning `HardTrapNeighborThreshold` and `StallRepathDelaySeconds` in `EnemyNavigationSettings` is the first lever.

## Known Issues / Gotchas

- The `EnemyUnit` class is split across multiple partial files (`EnemyUnit.cs`, `EnemyUnitMovement.cs`, `EnemyUnitStallRecovery.cs`, `EnemyUnitCrossLevelTraversal.cs`, `EnemyUnitRoutePlanning.cs`, `EnemyUnitSpatialState.cs`, `EnemyNavigationDiagnostics.cs`). Searching for a method requires checking all of them.
- The stall-refresh dedup system (`TrySuppressRedundantStallRecoveryPathRefresh`) can suppress legitimate repaths if `StallRefreshSuppressionEscalationThreshold` (3) consecutive suppressions have not yet been hit. If an enemy appears permanently stuck without any repath being issued, check `repeatedStallRecoveryRefreshSuppressionCount` and look for `stall_refresh_suppression_escalation` events in `RampTraversalTrace`.
- Body compression (shrinking `bodyRadius` toward `MinimumBodyHalfExtentFraction` during stalls) is intentional and expected when enemies are tightly packed on a ramp. It is not a bug; the radius expands back when stall clears.
- `TryResolveObstacleEdgeStall` is currently a no-op stub (returns `false`). Obstacle-edge stall handling is unimplemented.

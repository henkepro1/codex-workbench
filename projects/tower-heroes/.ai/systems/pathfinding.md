# Pathfinding

## Overview
`EnemyPathService` computes and caches multi-level shortest paths for enemies from spawn subcells to the player objective, routing through connectors as needed. It maintains one `EnemyRoutePlan` per spawn point at all times and responds to walk-topology changes (tower placement/removal) by rebuilding only affected routes. Individual enemies query `EnemyPathService` during rerouting to get a fresh plan from their current position; the service caches these plans per `(topologyVersion, startSubcell, nextCheckpointIndex)` so each unique starting position is solved at most once per topology state.

## How It Works

### Solver: ElevationShortestPathSolver
All actual pathfinding is BFS through `ElevationSubcellCoordinate` space. `TrySolve(elevationMapService, starts, goals, overlayBlocked, pathBuffer)` runs a standard BFS that:
1. Seeds the queue from all `starts` that pass `IsNavigationWalkable` and are not in `overlayBlocked`.
2. Expands via 4-directional `IsRegularNavigationWalkable` neighbors.
3. Also expands via connector graph edges fetched with `FillConnectorNeighborsNonAlloc` — these edges cross levels and are only walkable through `IsNavigationWalkable` (which permits connector-routeable subcells).
4. Terminates when a goal subcell is dequeued and reconstructs the path by following the `parents` dictionary back to a start.

The solver is stateless between calls (all internal collections are cleared on entry) and is held as a single instance inside `EnemyPathService`.

### Route Plan Structure: EnemyRoutePlan
A solved route is represented as `EnemyRoutePlan`, an immutable data object with parallel arrays:
- `SubcellPath` (`Vector2Int[]`) — ordered subcell XY coordinates (level is stored separately).
- `WorldPoints` (`Vector3[]`) — one entry per subcell plus a leading start point. `worldPoints[0]` is the enemy's actual world position; `worldPoints[i+1]` is the canonical navigation point for `subcellPath[i]`. For connector-routeable subcells the guide world point from `connectorTraversalGuideWorldPointBySubcell` is used; for portal subcells the endpoint world point is used; for regular subcells it is the subcell center.
- `WorldPointLevels` (`int[]`) — the elevation level for each world point; level changes identify cross-level (ramp) segments.
- `WorldPointStartSubcellIndices` (`int[]`) — maps each world point back to its subcell in `SubcellPath`.
- `NextCheckpointIndexBySubcell` (`int[]`) — for each subcell, which checkpoint is next after passing it.
- `RemainingDistanceToGoalByWorldPoint` (`float[]`) — monotonically decreasing remaining path length; used by the radar/progress UI.

### Configure and Initial Path Build
`EnemyPathService.Configure(spawnSubcells, checkpointCells)` stores spawn and checkpoint coordinates, calls `RebuildCheckpointCells` (which appends an optional dynamic final checkpoint), builds world position caches, and calls `RebuildActualPaths(fullRefresh)`. This runs `TryBuildPathInternal` for each spawn in sequence, sweeping through all checkpoint segments with the BFS solver and then calling `BuildRoutePlan` to assemble the `EnemyRoutePlan`.

### Dynamic Route Cache
Each resolved plan is stored as a `DynamicRoutePlanTemplate` in `dynamicRouteCache` keyed by `DynamicRouteCacheKey(topologyVersion, startSubcell, nextCheckpointIndex)`. `DynamicRoutePlanTemplate.CreateRoutePlan(routeStartWorldPosition)` stamps the enemy's actual starting world position onto `worldPoints[0]` without re-solving the BFS.

`SeedDynamicRouteSuffixTemplates` pre-seeds up to `MaxSeededDynamicRouteSuffixTemplatesPerSolvedRoute` (8) suffix entries per newly solved route by trimming the solved path from each of its first 8 subcells forward. This means any enemy at any of those subcells (same topology version) gets a free cache hit.

For builds with an overlay (the tower footprint being validated), a separate `overlayDynamicRouteCache` keyed by `(cacheKey, overlaySubcells)` stores overlay-specific plans.

### Topology Change Handling
`ElevationMapService` fires `WalkTopologyChanged` / `WalkTopologyRegionChanged` when a tower is placed or removed. `EnemyPathService` accumulates the change in `pendingWalkTopologyChange` and processes it the next time `RebuildActualPaths` is invoked (driven by `LateUpdate` or a direct call after occupancy changes). Only route plans whose subcell paths intersect the changed region are rebuilt; unaffected spawns keep their existing plan. All dynamic route caches are cleared on topology changes (topologyVersion is incremented).

### Per-Enemy Rerouting
When an enemy needs a new route (after a stall, after a topology change, or on spawn), `EnemyUnitRoutePlanning` calls:
1. `TryBuildRoutePlanByReusingCurrentRouteMembership` — if the enemy's remaining path tail has no level transitions and the enemy's current subcell is still on the current route plan, `EnemyRoutePlanReuseUtility.TryBuildTrimmedRoutePlan` slices the existing plan from the current subcell forward. This avoids a BFS solve.
2. If reuse fails, `TryBuildRoutePlanFromCurrentRouteableOrigin` — checks if the enemy's current world position is already on a routeable subcell and builds a fresh plan via `EnemyPathService.BuildRoutePlanFromWorldPositionAtLevel`.
3. If that fails, `EnsureRouteableRepathOrigin` calls `EnemyPathService.TryResolveNearestRouteableWorldPositionAtLevel` to find the nearest walkable, body-clear, routeable subcell by expanding outward from the enemy's current subcell, then builds a new plan from there.

### Build Validation
`CanBuildWithoutBlockingPaths(blockedSubcells, count)` checks whether placing a tower would disconnect any spawn. It runs overlay-path existence checks for each spawn whose current route intersects the proposed footprint and stores the resulting validated plans in `pendingBuildValidationRoutePlansBySpawn`. If the tower is then confirmed, `RebuildActualPaths` adopts these pre-validated plans directly (pending topology version match), avoiding a full re-solve at placement time.

### Reachability Cache
`EnemyPathTopologyReachabilityCache` stores a per-spawn boolean "can route at all" keyed by topology version. `EnemyPathService` uses `noOverlayReachabilityCache` to answer `CanResolveNoOverlayRouteFromSubcell` without a BFS for previously tested subcells.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `EnemyPathService` | `_Project/Scripts/GridSystem/EnemyPathService.cs` | Central service: route building, caching, topology change handling, build validation |
| `ElevationShortestPathSolver` | `_Project/Scripts/GridSystem/Elevation/ElevationShortestPathSolver.cs` | BFS solver over multi-level subcell graph including connector edges |
| `EnemyRoutePlan` | `_Project/Scripts/GridSystem/EnemyRoutePlan.cs` | Immutable per-enemy route: subcell path, world points, levels, checkpoint mapping, remaining distances |
| `DynamicRoutePlanTemplate` | `_Project/Scripts/GridSystem/` | Thin wrapper around `EnemyRoutePlan`; stamps `worldPoints[0]` with enemy's current position |
| `DynamicRouteCacheKey` | `_Project/Scripts/GridSystem/` | Cache key: `(topologyVersion, startSubcell, nextCheckpointIndex)` |
| `EnemyRouteDefinition` | `_Project/Scripts/GridSystem/EnemyRouteDefinition.cs` | Static authored route definition (spawn → checkpoints) used at startup |
| `EnemyPathTopologyReachabilityCache` | `_Project/Scripts/GridSystem/EnemyPathTopologyReachabilityCache.cs` | Per-topology per-subcell reachability boolean cache |
| `EnemyUnitRoutePlanning` (partial of `EnemyUnit`) | `_Project/Scripts/Waves/EnemyUnitRoutePlanning.cs` | Per-enemy rerouting logic: reuse, routeable-origin path, fallback nearest-routeable path |
| `EnemyRouteValidationKey` | `_Project/Scripts/Waves/` | Key type for per-enemy route validation |
| `NavigationWorldPath` | `_Project/Scripts/GridSystem/` | World-space path representation used by path indicator visuals |
| `EnemyPathIndicatorController` | `_Project/Scripts/GridSystem/EnemyPathIndicatorController.cs` | Visual arrow/line showing current path in the scene |

## Integration Points
- **Called by:** `GameplayMapInstaller` calls `Configure`. `EnemyUnit` (rerouting) calls `BuildRoutePlanFromWorldPositionAtLevel`, `TryResolveCurrentRouteableStartSubcellAtLevel`, `TryResolveNearestRouteableWorldPositionAtLevel`, and `CanResolveRouteFromWorldPositionAtLevel`. Tower placement controller calls `CanBuildWithoutBlockingPaths` and `IsOverlayPotentiallyBlockingCurrentSpawnRoutes`.
- **Calls into:** `ElevationMapService` (walkability, connector graph, world-point resolution); `ElevationShortestPathSolver` (BFS); `EnemyRoutePlanReuseUtility` (path trimming).
- **Shared state / data contracts:** `EnemyRoutePlan` is the primary data contract between `EnemyPathService` and each `EnemyUnit`. `TopologyVersion` is a monotonically increasing integer; any `DynamicRouteCacheKey` with a stale version is considered invalid. `ElevationWalkTopologyChange` carries the dirty region from `ElevationMapService` to `EnemyPathService`.

## Debug Guide

**Enemy cannot find a path at spawn:**
- `EnemyPathService.BuildRoutePlanFromWorldPositionAtLevel` will `Debug.LogError` with `StartIsNavigationSurface`, `StartIsBuildSurface`, and `StartIsNavigationWalkable` flags if route building fails. Check these in the console.
- `TryResolveNearestRouteableWorldPositionAtLevel` expanding outward should find a valid subcell unless the spawn is fully surrounded by towers. If that also fails, pathfinding has no exit and the level is unsolvable.

**Enemies stop moving after a tower is placed:**
- Check `TopologyVersion` in `EnemyPathService` has incremented. If `WalkTopologyChanged` was not fired, the occupancy change was not registered with `ElevationMapService`.
- `RebuildActualPaths` only rebuilds routes where `IsRoutePlanAffectedByTopologyChange` returns true. If the route plan's subcell path does not intersect the topology change bounding box, it is not rebuilt even if it is now blocked. Verify the topology change bounds cover the placed tower's subcells.
- After topology change, all `dynamicRouteCache` and `dynamicRouteExistsCache` entries are cleared. If an enemy's cached plan was from the old topology version, `currentRoutePlanTopologyVersion != pathService.TopologyVersion` triggers a repath.

**Route plan gives wrong world points on connector:**
- `BuildRoutePlan` uses `ResolveRouteWorldPoint` for regular subcells (subcell center or portal attachment face) and `connectorTraversalGuideWorldPointBySubcell` for connector-routeable subcells. If a connector subcell has no registered guide world point, `ResolveCanonicalNavigationWorldPoint` falls back to subcell center, which may mismatch the corridor center — the enemy could then fail `IsLegallyOccupyingActiveConnectorCrossLevelCorridor` on the first frame of ramp traversal.
- Verify `ElevationMapService.connectorTraversalGuideWorldPointBySubcell` was populated for all traversal subcells by checking `RegisterConnectorTraversalGuideWorldPoints`.

**Build validation incorrectly blocks a valid tower position:**
- `CanBuildWithoutBlockingPaths` uses `DoesOverlayIntersectRoutePlan` as a pre-filter before running the BFS. If the current route plan's `SubcellPath` contains a subcell that overlaps the tower footprint but an alternate route exists, the overlay BFS should find it. If the overlay BFS fails, check whether `overlayBlocked` correctly reflects only the tower footprint subcells (not additional bloat).

**Diagnostic logging:** `RampTraversalTrace` (static class) is the primary per-enemy diagnostic system for connector-related routing. `RecordRoutePlanBuilt` fires on every `BuildRoutePlanFromWorldPosition*` call and records the start, topology version, and resulting plan. Enable `RampTraversalTrace` output in the console filter to see a full trace of route assignments.

## Known Issues / Gotchas
- Dynamic route cache is keyed partly by `startSubcell` using exact equality. If two enemies are in the same subcell they share the same template, which is safe (they each get an independent `EnemyRoutePlan` with their own `worldPoints[0]`), but if a very large number of unique start positions accumulate the cache grows without bound within a single topology version. The cache is fully cleared on each topology increment.
- `SeedDynamicRouteSuffixTemplates` pre-seeds at most 8 suffix entries. Enemies that resume from subcell index 9 or later must trigger a fresh BFS on their first repath. This is an intentional performance trade-off.
- `pendingBuildValidationRoutePlansBySpawn` is only valid for one topology version and one specific blocked-subcell set. If the player moves the cursor between validity checks (producing a different footprint), the cached validation plans are discarded and a full re-solve runs.
- `TryBuildRoutePlanByReusingCurrentRouteMembership` is blocked when the remaining route tail contains any level transition (`DoesRemainingRouteTailContainLevelTransition`). This is a conservative safety measure: reusing a partial route while a ramp is in the suffix could produce a plan whose level metadata is inconsistent with the trimmed suffix. The cost is that enemies mid-ramp always trigger a fresh BFS repath on topology change.
- `noOverlayReachabilityCache` is a `null` reference until first populated. Null-check before using; the service initializes it lazily on first `Configure`.

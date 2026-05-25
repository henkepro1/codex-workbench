# Grid System

## Overview
The grid system is the spatial foundation for all gameplay. It partitions the map into cells and subcells (2 subcells per cell per axis), tracks which cells are terrain-blocked or build-blocked, manages runtime occupancy keyed by entity ID, and provides all world-to-cell and cell-to-world coordinate conversions. Both pathfinding and tower placement read from it. The grid also drives the visible line-renderer grid overlay.

## How It Works

### Initialization sequence (scene load)
`GameplayMapInstaller` (execution order -800) runs in `Awake` and drives the entire setup:

1. It reads the layout `Tilemap` to derive `runtimeOrigin` and `runtimeGridSize`, then calls `GridManager.ConfigureRuntimeLayout(origin, size)`. This allocates the four internal 2D arrays: `terrainBlockedCells`, `buildBlockedSubcells`, `buildOccupantKeysBySubcell`, and `navigationOccupantKeysBySubcell`.
2. It computes hidden boundary cells (one cell ring plus any `VisualEdgePaddingCells` from `GridSettings`) and passes them to `GridManager.ConfigureStaticTerrainBlockedCells` (navigation-blocked) and `ConfigureStaticBuildBlockedSubcells` (build-blocked).
3. It builds the `ElevationRuntimeMapDefinition` from `ElevationSurfaceAuthoring` and `ElevationConnectorAuthoring` objects and configures `ElevationMapService`.
4. `GameplayStaticObstacleBlockSource` is then asked to `CollectBuildBlockedSubcells` and `CollectNavigationBlockedSubcells`. For each `StaticObstacleAuthoring` under its root it samples the collider area against the subcell grid using a configurable coverage ratio (`buildSubcellCoverageThreshold`, default 20%), falling back to the collider centre subcell if no samples hit.
5. Route and spawn cells are also expanded into build-blocked subcells so enemies cannot be built over.

### Runtime occupancy
Placed towers write occupancy via `GridOccupant.Place(originSubcell, definition, occupyNavigationImmediately)`. This calls `ElevationMapService.OccupySubcells`, which internally records the `OccupantKey` (the tower's runtime GUID) into `buildOccupantKeysBySubcell` and/or `navigationOccupantKeysBySubcell`. Navigation occupation can be deferred: towers that block navigation only write the navigation layer when `TowerPlacementActivationController` calls `gridOccupant.ActivateNavigationOccupation()` after the placement delay expires. `GridOccupant.Remove()` releases both layers.

### Change notification
`GridManager` exposes two events: `WalkTopologyChanged` (fired when terrain or navigation occupancy changes) and `BuildSurfaceChanged` (fired when build occupancy changes). These are used by `EnemyPathService` and `RuntimeTowerRegistryService` to invalidate caches. Multiple simultaneous mutations should be wrapped in `BeginWalkTopologyBatch` / `EndWalkTopologyBatch` to coalesce the event into a single fire.

### Coordinate conversions
`TryWorldToCell` and `TryWorldToSubcell` floor-divide the local offset by `CellSize` or `SubcellSize`. `CellToWorldCenter` and `SubcellToWorldCenter` reverse this. The elevation layer adds a world-space offset from `ElevationMapService.GetSurfaceWorldOffset(level)` on top of the flat grid when computing visuals or placing objects.

## Key Classes & Files
| Class | File (relative to Assets/) | Role |
|---|---|---|
| `GridManager` | `_Project/Scripts/GridSystem/GridManager.cs` | Singleton. Owns all occupancy arrays; provides coordinate conversion and event notification. |
| `GridSettings` | `_Project/Scripts/GridSystem/GridSettings.cs` | ScriptableObject. CellSize, visual padding, line colours. |
| `GridOccupant` | `_Project/Scripts/GridSystem/GridOccupant.cs` | Per-tower component. Calls ElevationMapService to occupy/release subcells. |
| `GameplayMapInstaller` | `_Project/Scripts/GridSystem/GameplayMapInstaller.cs` | Scene bootstrap. Reads tilemap bounds, drives the full static configuration sequence. |
| `GameplayStaticObstacleBlockSource` | `_Project/Scripts/GridSystem/GameplayStaticObstacleBlockSource.cs` | Probes colliders at startup to produce build- and navigation-blocked subcell lists. |
| `StaticObstacleAuthoring` | `_Project/Scripts/GridSystem/` | Per-obstacle author data: level, blocking colliders, flags for build/nav blocking. |
| `ElevationMapService` | `_Project/Scripts/GridSystem/Elevation/ElevationMapService.cs` | Elevation-aware subcell occupancy store. All actual subcell read/write goes here. |
| `GridBuildInputController` | `_Project/Scripts/GridSystem/GridBuildInputController.cs` | Translates pointer input to placement intent. Listens to `WalkTopologyChanged` to clear preview cache. |
| `TowerPlacementPlaneLock` | `_Project/Scripts/GridSystem/TowerPlacementPlaneLock.cs` | Locks pointer-to-subcell projection to a specific elevation level while building. |

## Integration Points
- **Called by:** `GameplayMapInstaller` (startup configuration), `GridOccupant` (runtime occupancy writes), `GridBuildInputController` (coordinate queries per frame), `EnemyUnitMovement` and `EnemyPathService` (walkability queries).
- **Calls into:** `ElevationMapService` (subcell occupancy storage), `EnemyPathService` (notified on walk topology change), `RuntimeTowerRegistryService` (notified on build/walk topology change via events), `GameplayElevationPlaneViewController` (sorting layer for grid line visuals).
- **Shared state / data contracts:** `ElevationSubcellCoordinate` (level + x + y, used everywhere subcells cross system boundaries). `GridManager.WalkTopologyChanged` and `BuildSurfaceChanged` events. The `OccupantKey` string (runtime tower GUID) written into both occupancy layers.

## Debug Guide
**Grid lines do not appear:** Check `GridManager.SetGridVisualLevel` was called after `ElevationMapService` has a runtime map. `gridVisualLevel` defaults to 0 — if the map has no level 0 surface, `GetSurfaceWorldOffset` will throw.

**Tower placed but occupancy not updated:** Verify `GridOccupant.Place` was called and `ElevationMapService.Instance` is not null. If the tower's navigation flag is deferred, the navigation layer stays clear until `ActivateNavigationOccupation()` is called by `TowerPlacementActivationController`.

**Obstacle not blocking build:** The collider must be active and enabled. `GameplayStaticObstacleBlockSource` throws on disabled colliders. Check `buildSubcellCoverageThreshold` — if the obstacle is thin relative to the subcell size, coverage may fall below 20%.

**WalkTopologyChanged fires every frame:** A batch is not closed. Search for `BeginWalkTopologyBatch` calls missing their matching `EndWalkTopologyBatch`.

## Known Issues / Gotchas
- `ConfigureRuntimeLayout` resets `isTerrainLayoutConfigured` and `isBuildLayoutConfigured` to false, requiring the full static configuration sequence to re-run in the correct order.
- Grid visuals are rebuilt entirely on `SetGridVisualLevel`; do not call it every frame.
- Hidden boundary cells (the 1-cell ring) are blocked for both terrain and build purposes, so the effective playable grid is `GridSize - 2 * HiddenBoundaryCellCount` on each axis.
- `StaticObstaclePhysicsProbe` is created lazily in `Awake` and disposed in `OnDestroy`; do not call obstacle collection methods after the source is destroyed.

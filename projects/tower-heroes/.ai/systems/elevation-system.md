# Elevation System

## Overview
The elevation system defines the multi-level terrain model. Each "surface" is an independently positioned tilemap occupying one elevation level, described by a world offset, a set of occupied subcells, and placement/navigation flags. `ElevationMapService` is the central singleton runtime service that stores all per-level cell data as flat bool and string arrays, answers walkability and build-validity queries, tracks runtime tower occupancy, fires walk-topology change events, and provides coordinate conversion between base-world and level-world space. Connectors (ramps) sit on top of this model — see `elevation-ramp.md`.

## How It Works

### Authoring
Each elevation level has one or more `ElevationSurfaceAuthoring` MonoBehaviours in the scene. Each component holds:
- `surfaceId` — unique string identifier.
- `level` — integer level ID (0 = ground, higher = upper tiers).
- `tilemap` — the tilemap that defines the surface's footprint.
- `surfaceKind` — `ElevationSurfaceKind` (Flat, etc.).
- `placementRule` — `ElevationPlacementRule` (BuildableFlat, UnbuildableUneven, etc.).
- `supportsNavigation` — whether enemies can walk here.
- `sortingOrderBias` — rendering sort hint.
- `isDefaultHoverPriority` — used by hover resolution.

`ElevationSurfaceAuthoring.BuildRuntimeData(gridManager, levelOffsetResolver)` iterates the tilemap cells, converts each authored world position to a runtime grid cell (accounting for level world offset), then expands each cell into its constituent subcells. The result is `ElevationSurfaceRuntimeData` containing `OccupiedCellIndices`, `OccupiedSubcellIndices`, `WorldOffset`, and all flags.

All surfaces and connectors are bundled into an `ElevationRuntimeMapDefinition` (`Surfaces[]` + `Connectors[]` + `Levels[]`) and handed to `ElevationMapService.ConfigureRuntimeMap`.

### Runtime Map Configuration
`ElevationMapService.ConfigureRuntimeMap` does the following for each surface:
1. Calls `EnsureLevel(level, subcellCount)` to allocate per-level bool/string arrays if not already present. Each level gets independent arrays: `navigationSurfaceByLevel`, `buildSurfaceByLevel`, `unevenSurfaceByLevel`, `staticBuildBlockedByLevel`, `staticNavigationBlockedByLevel`, `runtimeBuildOccupantsByLevel`, `runtimeNavigationOccupantsByLevel`, `connectorTraversalSurfaceByLevel`, `connectorRouteableByLevel`.
2. Sets `navigation[subcellIndex] = true` for each occupied subcell where `SupportsNavigation` is true.
3. Sets `build[subcellIndex] = true` where `SupportsBuildPlacement` is true.
4. Records `worldOffsetByLevel`, `yOffsetByLevel`, and `sortingBiasByLevel`.

Connector registration follows (see `elevation-ramp.md`). After all data is loaded, `hasRuntimeMap` is set and `WalkTopologyChanged` + `BuildSurfaceChanged` events are fired.

### Coordinate System
Each elevation level has a `WorldOffset` (a `Vector2`). A "base-world" position is the position in level-0 / layout space; a "level-world" position is base-world plus the level's offset. `ToBaseWorldPosition(level, worldPos)` and `ToLevelWorldPosition(level, basePos)` are the two conversion methods used throughout the system.

`TryResolveBestSurfaceLevel` and `TryResolveHoveredSubcell` iterate levels from highest to lowest, converting the input world position to base-world for each level and checking whether the resulting subcell is on a valid surface. This enables the natural stacking behavior where upper levels take priority over lower ones.

### Walkability Queries
- `IsNavigationSurface(subcell)` — true if the subcell is on a regular navigation surface OR a connector routeable subcell.
- `IsRegularNavigationWalkable(subcell)` — true only for regular navigation surface subcells that are not statically blocked and not runtime-occupied.
- `IsNavigationWalkable(subcell)` — unified check: accepts both connector-routeable and regular navigation subcells, blocked by runtime occupants but NOT by static navigation blocked arrays (connectors bypass static navigation blocking).
- `IsBuildBlocked(subcell)` — true if the cell is not a build surface, is statically blocked, or is runtime-occupied.
- `IsConnectorRouteableSubcell(subcell)` — subcell is part of a connector traversal lane or portal.
- `IsConnectorTraversalSurfaceSubcell(subcell)` — subcell is within the body-width surface of a connector.

### Runtime Occupancy (Towers)
When a tower is placed, `OccupySubcells(subcells, count, occupantKey, occupyBuild, occupyNavigation)` writes the occupant key string into the corresponding `runtimeBuildOccupantsByLevel` / `runtimeNavigationOccupantsByLevel` entry. On removal, `ReleaseSubcells` clears those entries. Both operations fire `BuildSurfaceChanged` or `WalkTopologyChanged` (with a precise `ElevationWalkTopologyChange` bounding box covering the affected subcells).

### Walk Topology Change Notifications
`ElevationMapService` exposes `WalkTopologyChanged` (generic) and `WalkTopologyRegionChanged` (passes an `ElevationWalkTopologyChange` with min/max level and subcell bounds). `EnemyPathService` subscribes to these and schedules a path rebuild, invalidating the route caches. `ElevationWalkTopologyChange.CreateFullRefresh()` forces all routes to be rebuilt; incremental changes carry a tight bounding region so only affected spawn routes are re-solved.

### Save/Restore
`ElevationMapService` implements `IPersistable`. It saves only `ElevationMapState.HoveredLevel` (the current camera-facing level) and restores it on load.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `ElevationSurfaceAuthoring` | `_Project/Scripts/GridSystem/Elevation/ElevationSurfaceAuthoring.cs` | Scene component; bakes surface tilemap into `ElevationSurfaceRuntimeData` |
| `ElevationSurfaceRuntimeData` | `_Project/Scripts/GridSystem/Elevation/` | Baked surface data: level, flags, occupied cell/subcell index sets, world offset |
| `ElevationSurfaceKind` | `_Project/Scripts/GridSystem/Elevation/` | Enum: Flat, etc. |
| `ElevationPlacementRule` | `_Project/Scripts/GridSystem/Elevation/` | Enum: BuildableFlat, UnbuildableUneven, etc. |
| `ElevationMapService` | `_Project/Scripts/GridSystem/Elevation/ElevationMapService.cs` | Central runtime service: all per-level arrays, walkability/build queries, occupancy, topology events, coordinate conversion |
| `ElevationRuntimeMapDefinition` | `_Project/Scripts/GridSystem/Elevation/ElevationRuntimeMapDefinition.cs` | Thin container: `Surfaces[]`, `Connectors[]`, `Levels[]` passed to `ConfigureRuntimeMap` |
| `ElevationMapState` | `_Project/Scripts/GridSystem/Elevation/` | Serialized save state (only `HoveredLevel`) |
| `ElevationCellCoordinate` | `_Project/Scripts/GridSystem/Elevation/` | Struct: `(Level, CellX, CellY)` — full-cell precision |
| `ElevationSubcellCoordinate` | `_Project/Scripts/GridSystem/Elevation/` | Struct: `(Level, SubcellX, SubcellY)` — subcell precision; primary coordinate used everywhere |
| `ElevationLevelId` | `_Project/Scripts/GridSystem/Elevation/` | Thin wrapper/constants for level integer IDs |
| `ElevationWalkTopologyChange` | `_Project/Scripts/GridSystem/Elevation/` | Describes what changed: full refresh or bounded min/max level and subcell region |
| `ElevationShortestPathSolver` | `_Project/Scripts/GridSystem/Elevation/ElevationShortestPathSolver.cs` | BFS pathfinder that consults `ElevationMapService` for walkability and connector graph edges |
| `AuthoredLevelWorldOffsetResolver` | `_Project/Scripts/GridSystem/Elevation/` | Resolves authored-world to runtime-world offsets per level |

## Integration Points
- **Called by:** `GameplayMapInstaller` builds `ElevationRuntimeMapDefinition` from `ElevationSurfaceAuthoring` and `ElevationConnectorAuthoring` components and calls `ConfigureRuntimeMap`. Tower placement calls `OccupySubcells` / `ReleaseSubcells`. `EnemyPathService` subscribes to `WalkTopologyChanged`. Rendering (`GameplayElevationPlaneViewController`, `ElevationRuntimeLevelViewTarget`) queries `GetSurfaceWorldOffset` and `CurrentHoveredLevel`. UI and build-preview systems query `IsBuildBlocked` and `CanBuildSubcells`.
- **Calls into:** `GridManager` (subcell-index arithmetic, bounds checks, world↔subcell conversions); `SaveManager` (state persistence registration).
- **Shared state / data contracts:** `ElevationSubcellCoordinate` is the universal key type. Per-level bool arrays are indexed by `(subcell.y * subgridWidth) + subcell.x`. `ElevationWalkTopologyChange` carries the delta that `EnemyPathService` uses to decide which routes to rebuild.

## Debug Guide

**Enemies not walking on a surface:**
- Check `IsNavigationWalkable(subcell)` returns true. If `IsNavigationSurface` is false, the surface was not registered with `SupportsNavigation = true` or the tilemap did not cover that cell.
- Check `staticNavigationBlockedByLevel` — a connector may have projected `NavigationBlockedSubcells` over this cell. Connector navigation-blocked subcells are explicitly *not* the traversal lane (the lane is removed from the navigation-blocked set), but the connector footprint perimeter still gets blocked.
- Runtime occupancy: `ReadLevelString(runtimeNavigationOccupantsByLevel, subcell)` should return `null` for unoccupied cells.

**Tower placement silently fails or allows invalid position:**
- `IsBuildBlocked` checks build surface flag, `staticBuildBlockedByLevel`, then `runtimeBuildOccupantsByLevel`. If the cell's surface was authored with `placementRule = UnbuildableUneven`, it will not be in `buildSurfaceByLevel`.
- `EnemyPathService.CanBuildWithoutBlockingPaths` is the upstream gate — it simulates the tower's blocked subcells as overlay and re-runs pathfinding. If this returns false, `IsBuildBlocked` state is never changed.

**Hover / click registers wrong level:**
- `TryResolveHoveredSubcell` iterates from highest level down. If a higher level's surface overlaps the click position but is not a valid navigation or build surface, the query falls through to a lower level. Use `hasInteractionLevelCeiling` / `SetInteractionLevelCeiling` to restrict hover priority when the UI is in single-level mode.

**Walk topology events not firing:**
- Occupancy changes always call `NotifyWalkTopologyChanged`. If `EnemyPathService` is not receiving events, check that it subscribed to both `WalkTopologyChanged` and `WalkTopologyRegionChanged` in `OnEnable`.

## Known Issues / Gotchas
- Level integer IDs are sparse; code uses `Dictionary<int, bool[]>` not arrays. Do not assume levels are contiguous.
- `ElevationMapService` is a `SingletonBehaviour` — there is exactly one instance. Calling methods before `ConfigureRuntimeMap` (`hasRuntimeMap == false`) throws `InvalidOperationException`.
- `ClearRuntimeMap` is called before each `ConfigureRuntimeMap`. Do not hold references to per-level arrays across a map load — they will be replaced.
- `IsNavigationWalkable` bypasses `staticNavigationBlockedByLevel` for connector-routeable subcells. This is intentional: connectors must remain walkable for pathfinding even if they overlay a navigation-blocked static region.
- `SortedLevels` is built from unique levels seen during `ConfigureRuntimeMap`. If a connector spans levels not covered by any surface, those levels are still added to the sorted list.

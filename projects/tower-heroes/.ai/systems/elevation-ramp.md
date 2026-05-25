# Elevation Ramp (Connector System)

## Overview
Multi-level terrain uses "connectors" (ramps, stairs, tunnel links, bridge access) to let enemies traverse between elevation levels. Each connector is authored in the Unity scene and baked at startup into `ElevationConnectorRuntimeData`, which describes the traversal lane, the body-width surface, portal subcells at each end, and the sets of subcells that block building or navigation over the connector footprint. At runtime, `EnemyUnitCrossLevelTraversal` (a partial of `EnemyUnit`) takes over movement whenever the active route segment crosses a connector, enforcing the corridor geometry and body-clearance rules that keep enemies on the authored ramp path.

## How It Works

### Authoring and Bake (scene load)
1. `ElevationConnectorAuthoring` is a MonoBehaviour placed in the scene. It holds a `connectorId`, a `footprintTilemap`, `start`/`end` `ElevationPointAnchor` transforms, optional intermediate anchors, and a `bidirectional` flag. The connector kind is `ElevationConnectorKind` (Ramp, Stairs, TunnelLink, BridgeAccess).
2. At map install time, `BuildRuntimeData(gridManager, levelOffsetResolver, traversalSurfaceBodyRadius)` is called.
3. The footprint tilemap is rasterized into a flat `HashSet<int>` of subcell indices (level-independent 2D positions). These serve as the spatial domain for all subsequent operations.
4. `ElevationConnectorFootprintProjectionUtility.ResolveProjectedEndpointFromAuthoredSegment` projects the start and end `ElevationPointAnchor` positions onto the nearest footprint subcell boundary, producing an `ElevationConnectorEndpointProjectionResult` per endpoint. This records the exact `ElevationSubcellCoordinate`, world point, and `ElevationConnectorEndpointAttachmentSide` (Up/Down/Left/Right) — the cardinal direction the portal faces toward the regular surface.
5. Intermediate anchor positions are likewise snapped to their nearest footprint subcell via `ResolveRequestedSubcellFromConnectorAuthoredPosition`. Duplicate consecutive anchors are collapsed.
6. `ElevationConnectorTraversalLaneBuilder.BuildSegmentPath` runs a BFS/scan for each anchor-to-anchor segment through the footprint, producing the ordered `traversalSubcells` (the center-line lane) and corresponding `traversalEdges`.
7. `ElevationConnectorTraversalSurfaceBuilder.BuildTraversalSurface` expands the lane into a `traversalSurfaceSubcells` set by sweeping a capsule of radius `traversalSurfaceBodyRadius` along each lane segment and including every footprint subcell whose center falls within `halfSubcellDiagonal + bodyRadius`. This is the region the body-clearance checks consult during runtime movement.
8. `ElevationConnectorEndpointPortalResolver.ResolvePortalSubcells` selects the traversal-surface subcells at each end that abut the attachment side — these are `StartPortalSubcells` and `EndPortalSubcells`.
9. Build-blocked and navigation-blocked subcell sets are computed by projecting the footprint across all `affectedLevels`, then **removing** the traversal lane subcells from the navigation-blocked set (the lane must stay walkable for pathfinding).
10. The result is stored in `ElevationConnectorRuntimeData` and validated with `Validate()`.

### Registration in ElevationMapService
`ElevationMapService.ConfigureRuntimeMap` iterates all connectors and calls:
- `MarkConnectorTraversalSurfaceSubcells` — fills `connectorTraversalSurfaceByLevel` and `connectorTraversalSurfaceConnectorIdBySubcell` (owner lookup).
- `MarkConnectorRouteableTraversalSubcells` — fills `connectorRouteableByLevel` and `connectorTraversalIndexBySubcell` (ordered progress index 0..N-1).
- `MarkConnectorRouteablePortalSubcells` — marks start/end portal subcells as routeable (progress order -1 / N).
- `AddConnectorTraversalLaneEdges` — inserts directed edges into `connectorNeighbors` / `connectorPredecessors`.
- `AddConnectorPortalSurfaceAttachments` — wires each portal subcell to its adjacent regular navigation subcell, completing the graph so `ElevationShortestPathSolver` can cross into and out of connectors.

### Runtime Traversal (per-frame movement)
1. Each frame, `EnemyUnit` advances along its `EnemyRoutePlan.WorldPoints` array. Each world point carries a level in `WorldPointLevels`.
2. When `nextPathPointIndex - 1` and `nextPathPointIndex` are at different levels, `TryAcceptActiveConnectorCrossLevelDisplacement` takes control.
3. It first resolves the active segment via `TryResolveActiveConnectorCrossLevelSegment`, which confirms both endpoints are connector-routeable subcells owned by the same connector.
4. `IsLegallyOccupyingActiveConnectorCrossLevelCorridor` projects the enemy's world position onto the segment and verifies perpendicular deviation is within `corridorHalfWidth = max(compressedBodyRadius, subcellSize * 0.35)`.
5. `BuildConnectorAuthoritativeRequestedDisplacement` computes the forward movement along the segment, then `EnemyConnectorTransitionTraversalUtility.FindLargestAllowedDisplacement` binary-searches for the largest fraction of that displacement that keeps the enemy inside the corridor.
6. `FindLargestCrossLevelBodyClearDisplacement` further binary-searches for the maximum displacement where `IsConnectorOwnedTraversalSurfaceCircleClear` returns true — i.e., the body circle does not overlap any non-surface or blocked subcell owned by this connector.
7. `ResolveCrossLevelCandidateSurfaceLevel` picks which level is "active" based on the midpoint of the segment: below 50% progress → start level, at or above → end level.
8. Route progress is tracked via `ElevationMapService.IsConnectorRouteProgressAtOrBeyond`, which converts subcell coordinates to their progress order (portal start = -1, traversal interior = index 0..N-1, portal end = N). A strict-greater rule prevents start-portal siblings from auto-satisfying a different portal subcell's path point.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `ElevationConnectorAuthoring` | `_Project/Scripts/GridSystem/Elevation/ElevationConnectorAuthoring.cs` | Scene-placed component; bakes all connector runtime data at map load |
| `ElevationConnectorRuntimeData` | `_Project/Scripts/GridSystem/Elevation/ElevationConnectorRuntimeData.cs` | Immutable data object: lane, surface, portals, edges, blocked sets |
| `ElevationConnectorKind` | `_Project/Scripts/GridSystem/Elevation/ElevationConnectorKind.cs` | Enum: Ramp, Stairs, TunnelLink, BridgeAccess |
| `ElevationConnectorTraversalSurfaceBuilder` | `_Project/Scripts/GridSystem/Elevation/ElevationConnectorTraversalSurfaceBuilder.cs` | Expands traversal lane to body-width surface via capsule sweep |
| `ElevationConnectorTraversalLaneBuilder` | `_Project/Scripts/GridSystem/Elevation/` | BFS through footprint to build ordered traversal lane |
| `ElevationConnectorFootprintProjectionUtility` | `_Project/Scripts/GridSystem/Elevation/ElevationConnectorFootprintProjectionUtility.cs` | Projects authored anchor positions onto footprint subcell boundaries |
| `ElevationConnectorEndpointPortalResolver` | `_Project/Scripts/GridSystem/Elevation/` | Selects portal subcells at each connector end |
| `ElevationMapService` | `_Project/Scripts/GridSystem/Elevation/ElevationMapService.cs` | Runtime registry: owns all per-level bool arrays, connector graphs, ownership lookups, progress logic |
| `EnemyUnitCrossLevelTraversal` (partial of `EnemyUnit`) | `_Project/Scripts/Waves/EnemyUnitCrossLevelTraversal.cs` | Per-frame corridor constraint, body clearance, level reconciliation during ramp traversal |
| `EnemyConnectorTransitionTraversalUtility` | `_Project/Scripts/Waves/` | Binary-search helper for largest allowed displacement inside the corridor |
| `ConnectorNavigationLineBuilder` | `_Project/Scripts/GridSystem/Elevation/ConnectorNavigationLineBuilder.cs` | Builds the visual navigation line along the connector |

## Integration Points
- **Called by:** `GameplayMapInstaller` calls `ElevationConnectorAuthoring.BuildRuntimeData` at startup, then passes results to `ElevationMapService.ConfigureRuntimeMap`. `EnemyUnit` (movement loop) calls into `EnemyUnitCrossLevelTraversal` methods each frame when a cross-level route segment is active.
- **Calls into:** `ElevationMapService` (surface/routeability queries, ownership checks, progress comparison); `EnemyPathService` (route plan building from connector subcell origins); `GridManager` (subcell coordinate conversions); `AuthoredLevelWorldOffsetResolver` (level world-offset translation).
- **Shared state / data contracts:** `ElevationConnectorRuntimeData` is the baked output of authoring and the input to `ElevationMapService`. `EnemyRoutePlan.WorldPointLevels` signals level transitions to the movement system. `connectorTraversalIndexBySubcell` in `ElevationMapService` gives each traversal subcell its monotonic progress order.

## Debug Guide

**Enemy stops moving at bottom or top of ramp:**
- Check `RampTraversalTrace` log entries (static diagnostic class; search for `RecordEnemyCrossLevelStall` output). It records the enemy's world position, current surface level, next path point, corridor segment endpoints, and deviation from the corridor.
- Confirm `TryResolveActiveConnectorCrossLevelSegment` succeeds: both world points must map to connector-routeable subcells owned by the same connector. If it returns false with reason `endpoints_not_both_connector_routeable` or `different_connector_owner`, the route plan has a path-point that does not land on the expected connector — likely a route-build issue.
- If stuck at the portal entry: verify `IsLegallyOccupyingActiveConnectorCrossLevelCorridor` returns true. If the enemy's position deviates more than `corridorHalfWidth` from the guide segment, cross-level movement will not engage. This can happen if the enemy arrives at the portal from an unexpected angle.
- If stuck mid-ramp: check body clearance. `FindLargestCrossLevelBodyClearDisplacement` returning zero means `IsConnectorOwnedTraversalSurfaceCircleClear` never accepts any forward position. The traversal surface may be too narrow for the body radius — check `traversalSurfaceBodyRadius` vs `gridManager.SubcellSize`.

**Enemy overshoots level change / wrong level reported:**
- `ResolveCrossLevelCandidateSurfaceLevel` is the authoritative level picker during the cross-level segment. It flips at the 50% progress mark. If `currentSurfaceLevel` diverges unexpectedly, check `TryResolveCommittedConnectorSurfaceLevelForCrossLevelSegment` — it can commit early to the end level if the enemy's position is already connector-routeable on the end level and owned by the same connector.

**Route progress skipping connector:**
- `IsConnectorRouteProgressAtOrBeyond` uses a strict-greater rule for start-portal progress order -1. If two start-portal sibling subcells exist and a unit enters any one of them, it must not auto-satisfy a different sibling's path point. If you see enemies teleporting past the ramp interior, check whether this gating is being bypassed.

## Known Issues / Gotchas

- **Degenerate first route segment at portal exit (fixed 2026-05-25):** When `EnemyPathService.BuildRoutePlan` built the first world point for a connector portal subcell, it previously called `NormalizeRouteStartWorldPosition`, which projected the enemy's actual position onto a very short endpoint-to-guide segment. If the enemy was already past the guide, the projection collapsed to the guide point, making `worldPoints[0] == worldPoints[1]` — a degenerate segment. The corridor then advanced to `worldPoints[1]→worldPoints[2]` and the enemy could not enter it. Fix: `BuildRoutePlan` now uses the raw `routeStartWorldPosition` for `worldPoints[0]` instead of the normalized projection. See change `2026-05-25-090113`.

- **Traversal surface body-ownership too narrow (fixed 2026-05-25):** The traversal surface initially only included subcells directly on the traversal lane. When `traversalSurfaceBodyRadius` was larger than half a subcell, the enemy's body circle extended outside the surface and `IsConnectorOwnedTraversalSurfaceCircleClear` rejected all forward positions. Fix: `ElevationConnectorTraversalSurfaceBuilder` now sweeps a full capsule of radius `bodyRadius + halfSubcellDiagonal` along each guide segment. See change `2026-05-25-092657`.

- **First traversal guide being consumed prematurely (fixed 2026-05-25):** In `BuildRoutePlan`, when `subcellPath[0]` was a connector-routeable subcell, `worldPoints[1]` was being set to `normalizedRouteStartWorldPosition` (the enemy's actual position) rather than the guide. This collapsed the first corridor segment to zero length and the second corridor started one step too early. Fix: connector-routeable start subcells now still use the canonical guide for their world point, while only `worldPoints[0]` uses the raw start position. See change `2026-05-25-094501`.

- **Start portal sibling auto-promotion bug (fixed 2026-05-25):** Two portal subcells at the same end share progress order -1. A plain `>=` comparison allowed any portal subcell to auto-satisfy any other portal subcell in the same portal group, letting enemies skip the ramp interior. Fix: added strict-greater check for progress order -1 to require the unit actually advance into the traversal interior. See `ElevationMapService.IsConnectorRouteProgressAtOrBeyond`.

- **Connector exit to regular surface body clearance (fixed 2026-05-25):** After completing the connector, the first step onto the regular surface needed its own body-clear check. Previously the body-clear after exiting could reject moves that were valid on the regular surface. Fix: connector-to-regular exit now applies regular same-level body clearance after confirming connector-owned clearance at the current position. See change `2026-05-25-142559`.

- **Surface-only subcells inside the connector footprint:** If a subcell is inside `TraversalSurfaceSubcells` but not in `TraversalSubcells`, it is body-surface space but has no route progress order. `IsConnectorSurfaceButNotConnectorRouteable` returns true for these. Enemies whose repathing origin falls on such a subcell are redirected to the nearest routeable subcell to avoid being stranded on the surface margin.

- **Connector ownership conflicts throw at startup:** `ElevationMapService` throws `InvalidOperationException` if two connectors claim overlapping traversal-surface or routeable subcells. This is a content authoring error — the connector footprint tilemaps must not overlap.

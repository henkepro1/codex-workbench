# Tower Placement

## Overview
Tower placement manages the full lifecycle from the player selecting a tower type through previewing, validating, committing, and activating a placed tower. It tracks all live towers at runtime in `RuntimeTowerRegistryService`, enforces that no build blocks all enemy paths, and handles the construction animation phase before a tower becomes combat-operational.

## How It Works

### Selection and preview (per-frame)
`GridBuildInputController.Update` runs every frame. If `TowerBuildSelectionService` has a selection and `BuildInventoryService` has quantity:

1. `TowerPlacementPlaneLock` is synced to the currently viewed elevation level from `GameplayElevationPlaneViewController`.
2. The pointer world position is read and converted to an `ElevationSubcellCoordinate` via `TowerPlacementPlaneLock.TryResolvePlacementSubcell`, which projects the world point onto the locked elevation plane.
3. `TowerDefinition.GetSnappedOriginSubcell` snaps the hovered subcell to the tower's footprint origin.
4. `RuntimeTowerRegistryService.EvaluateTowerPlacement` returns a `TowerPlacementValidationResult`. This result is cached by (definitionId, originSubcell, validationVersion); it is invalidated whenever `GridManager.BuildSurfaceChanged` or `WalkTopologyChanged` fires.
5. `TowerPlacementPreviewController.ShowPreview` renders the footprint green or red depending on `result.CanPlace`. Affordability is checked separately from placement validity.

### Placement validation rules (inside `ResolvePlacementRules`)
`RuntimeTowerRegistryService` runs these checks in order:
1. `ElevationMapService.CanBuildSubcells` — all footprint subcells must be build-unoccupied.
2. If the tower `BlocksBuildSpace`, no overlap with any other `PendingBuildReservation` (towers that are ordered but not yet spawned by the player unit).
3. If the tower `BlocksNavigation`, build a combined overlay of: the new footprint, all `pendingNavigationReservations` (towers placed but not yet fully activated), and all pending build reservations' navigation footprints. Query `EnemyPathService.IsOverlayPotentiallyBlockingCurrentSpawnRoutes` for a fast AABB pre-filter, and only call the expensive `CanBuildWithoutBlockingPaths` pathfind if the pre-filter passes. If paths would be blocked, return `TowerPlacementFailureReason.NavigationRouteBlocked`.

### Commit (LateUpdate)
On click, `GridBuildInputController.LateUpdate` dequeues `PendingBuildPlacementRequest`. It re-validates affordability and quantity, then calls `PlayerUnitRuntimeService.IssueImmediateBuildOrder` (single tower) or `IssueBuildOrder` (batch, when the hold-to-continue-build hotkey is held). The player unit walks to the site and calls `RuntimeTowerRegistryService.PlaceNewTower` or `PlaceUnderConstructionTower`.

### Spawn
`RuntimeTowerRegistryService.SpawnTower`:
1. Looks up the `GameObject` prefab in `TowerPrefabCatalog` by `definitionId`.
2. Instantiates at the world position derived from `TowerDefinition.GetPlacementWorldPositionFromOriginSubcell`.
3. Assigns `RuntimeEntityId`, calls `GridOccupant.Place` (writes build occupancy; navigation deferred if under construction).
4. If under construction, calls `TowerPlacementActivationController.InitializeConstruction(remainingSeconds)`, which sets phase to `Building` and disables `AttackModule`.
5. If ready immediately, calls `InitializePlacement(delaySeconds)` which transitions to `WaitingForActivation`.
6. Fires `TowerSpawned` event.

### Activation lifecycle
`TowerPlacementActivationController` tracks three phases: `Building` → `WaitingForActivation` → `Built`. `TowerPlacementActivationSimulationService` ticks registered controllers each combat frame:
- During `Building`, `SetConstructionRemainingSeconds` ticks down; when complete, `CompleteConstruction` is called externally by `RuntimeTowerRegistryService.CompleteUnderConstructionTower`.
- During `WaitingForActivation`, `TickActivation` counts down `RemainingDelaySeconds`. When it reaches zero, `ActivateNow` calls `gridOccupant.ActivateNavigationOccupation()` (writing the navigation layer to `ElevationMapService`, which fires `WalkTopologyChanged`) and enables `AttackModule`. The `PendingNavigationReservationReleased` event fires, which causes `RuntimeTowerRegistryService` to remove the pending navigation reservation and re-invalidate the placement validation cache.

### Removal
`RemovePlacedTower` calls `gridOccupant.Remove()`, fires `TowerRemoved`, and destroys the instance.

## Key Classes & Files
| Class | File (relative to Assets/) | Role |
|---|---|---|
| `RuntimeTowerRegistryService` | `_Project/Scripts/Entities/Towers/RuntimeTowerRegistryService.cs` | Singleton. Owns all placed tower state; runs validation; spawns/removes instances. |
| `RuntimePlacedTowerState` | `_Project/Scripts/Entities/Towers/RuntimePlacedTowerState.cs` | Serializable runtime state per tower (GUID, definitionId, origin, delay, targeting state). |
| `TowerPlacementActivationController` | `_Project/Scripts/Entities/Towers/TowerPlacementActivationController.cs` | Per-tower. Manages Building → WaitingForActivation → Built phases. |
| `TowerPlacementActivationSimulationService` | `_Project/Scripts/Entities/Towers/TowerPlacementActivationSimulationService.cs` | Singleton. Ticks all registered activation controllers each combat frame. |
| `TowerPlacementValidationResult` | `_Project/Scripts/Entities/Towers/TowerPlacementValidationResult.cs` | Value type: CanPlace bool, FailureReason, diagnostic flags. |
| `TowerPlacementValidationCache` | `_Project/Scripts/Entities/Towers/TowerPlacementValidationCache.cs` | Simple dict cache keyed on (definitionId, originSubcell, ignoredReservationId, version). |
| `TowerPlacementFailureReason` | `_Project/Scripts/Entities/Towers/TowerPlacementFailureReason.cs` | Enum: None, BuildSurfaceBlocked, NavigationRouteBlocked, ObjectiveBaseAlreadyPlaced. |
| `TowerPlacementIntent` | `_Project/Scripts/Entities/Towers/TowerPlacementIntent.cs` | Value type passed from input controller to preview and placement queue. |
| `GridBuildInputController` | `_Project/Scripts/GridSystem/GridBuildInputController.cs` | Reads pointer, resolves intent, feeds placement queue. |
| `TowerPlacementPlaneLock` | `_Project/Scripts/GridSystem/TowerPlacementPlaneLock.cs` | Projects pointer onto a fixed elevation level plane. |
| `TowerBuildSelectionService` | `_Project/Scripts/Entities/Towers/TowerBuildSelectionService.cs` | Tracks which tower type the player has currently selected for building. |
| `BuildInventoryService` / `BuildInventoryState` | `_Project/Scripts/Entities/Towers/BuildInventory*.cs` | Tracks how many of each tower type are available to build. |
| `TowerPrefabCatalog` | `_Project/Scripts/Entities/Towers/TowerPrefabCatalog.cs` | ScriptableObject mapping definitionId → prefab. |
| `TowerConstructionVisualController` | `_Project/Scripts/Entities/Towers/TowerConstructionVisualController.cs` | Drives the under-construction sprite/progress bar visuals. |

## Integration Points
- **Called by:** `GridBuildInputController` (placement intent and commit), `PlayerUnitRuntimeService` (issues the actual build order), `SaveManager` (persists/restores `RuntimeTowerRegistryState`).
- **Calls into:** `ElevationMapService` (subcell occupancy and buildability), `EnemyPathService` (path block validation), `GridManager` (walk topology batching, world/cell conversions), `TowerPrefabCatalog` (prefab lookup), `CurrencyWalletService` (affordability), `TowerTargetingPresetService` (initial targeting state).
- **Shared state / data contracts:** `ElevationSubcellCoordinate` (origin and footprint subcells). `RuntimePlacedTowerState` serialized by `SaveManager`. `PlacementValidationVersion` integer incremented on every invalidation — the validation cache uses this as a freshness key.

## Debug Guide
**Tower cannot be placed (red preview) but position looks valid:** Check `TowerPlacementValidationResult.FailureReason` logged by `TowerPlacementDiagnosticsLogFormatter`. Most likely causes: (1) `BuildSurfaceBlocked` — another tower's `pendingBuildReservation` overlaps (common during rapid queue builds); (2) `NavigationRouteBlocked` — the new footprint combined with other pending towers seals a route.

**Tower stuck in `Building` phase forever:** `CompleteUnderConstructionTower` was not called by the player unit after construction finished. Check `PlayerUnitController` and the build command state machine.

**Activation delay never expires:** `TowerPlacementActivationSimulationService` is not in the scene, or `GameplaySimulationService.IsCombatPaused` is true.

**Navigation not updating after placement:** The `PendingNavigationReservationReleased` event on `TowerPlacementActivationController` was not received by `RuntimeTowerRegistryService` — likely because `AttachPlacementActivation` was not called (only done for `BlocksNavigation` towers).

## Known Issues / Gotchas
- Towers under construction (`Building` phase) are excluded from `CaptureState` (save) — only towers in `WaitingForActivation` or `Built` are saved. If the game saves mid-construction, the under-construction tower is lost on reload.
- `PurgeDestroyedTowers` is called defensively before many queries to remove externally-destroyed instances. If a tower is destroyed without going through `RemovePlacedTower`, the cleanup is deferred until the next registry query.
- The `ContinueBuildPlacement` hotkey creates a shared `activePlacementBatchId` so the player unit can chain build orders. Clearing this batch ID prematurely will cause the unit to restart pathfinding for each tower.

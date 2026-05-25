# Wave Spawning

## Overview
Controls the full lifecycle of enemy waves — which wave types are selected and when, the moment-to-moment drip of individual enemy spawns within a wave, and the runtime tracking of every live enemy from instantiation through death or goal-reach. The system also handles save/restore of both the wave schedule and all live enemies so runs can survive app restarts.

## How It Works

**Wave selection — `WaveManager`.** `WaveManager` holds a `WaveSetDefinition` (a ScriptableObject array of `WaveDefinition` assets) and maintains a queue of `upcomingWaveDefinitionIndices`. When `BeginNewRun` is called, `EnsureUpcomingQueueFilled` populates the queue to `upcomingPreviewCount` slots using a weighted-random selection algorithm (`SelectNextWaveDefinitionIndex`). Selection enforces two constraints driven by `recentWaveDefinitionHistory`:
- `preventImmediateRepeat` — the last queued wave is excluded.
- `maxOccurrencesPerWindow` within `rollingConstraintWindowSize` — no single wave type can appear more than N times in a sliding window of recent + upcoming wave indices.

Each `WaveDefinition` has a `SelectionWeight` and an `AutoStartDelaySeconds`. The countdown timer ticks down via `GameplaySimulationService.CombatTicked`. When the countdown reaches zero (or the player presses "start wave early"), `BeginWave` dequeues the head, increments `CurrentWaveNumber`, sets `isWaveActive`, and fires `StateChanged`. `WaveManager.CompleteActiveWave` is called by `WaveSpawner` after the last enemy of a wave has been queued for spawn; `WaveManager` then re-fills the upcoming queue and restarts the countdown.

**Enemy spawning — `WaveSpawner`.** `WaveSpawner` subscribes to `WaveManager.StateChanged` and `GameplaySimulationService.CombatTicked`. When a wave becomes active it calls `BeginWave`, which records `activeWaveNumber`, resets `nextEntryIndex` and `secondsUntilNextSpawn`, and plays the wave start SFX.

Each combat tick with an active spawn sequence, `AdvanceSpawnSequence` fires:
1. It reads the current `WaveSpawnEntry` from `waveDefinition.Entries[nextEntryIndex]`. A `WaveSpawnEntry` specifies an `EnemyPrefab` (GameObject), a `Count`, a `SpawnIntervalSeconds`, and a `SpawnPointIndex`.
2. `SpawnEnemy` resolves the enemy type's `EnemySaveIdentity.EnemyId` from the prefab, then delegates to `EnemyRuntimeService.SpawnNewWaveEnemy`.
3. After spawning, `nextSpawnIndexWithinEntry` increments. When all `Count` enemies of this entry are spawned, `nextEntryIndex` advances and `secondsUntilNextSpawn` resets to zero (entries spawn back-to-back; intra-entry spacing is `SpawnIntervalSeconds`).
4. When all entries are exhausted, `WaveManager.CompleteActiveWave()` is called to end the wave.

**Enemy instantiation and initialization — `EnemyRuntimeService`.** `SpawnNewWaveEnemy` looks up the prefab from `EnemyPrefabCatalog.GetPrefab(enemyId)`, instantiates it under the `enemyRuntimeRoot` Transform configured by `WaveSpawner`, ensures an `ElevationRuntimeLevelViewTarget` component exists (adding one if missing), and calls `EnemyUnit.Initialize(spawnPointIndex, waveSequenceNumber)`.

`Initialize` caches all required singletons (`GridManager`, `EnemyPathService`, `ElevationMapService`, `EnemyCrowdService`, `EnemyCrowdPriorityService`), resolves a body-clear spawn position on the route start subcell (binary-searching along the first connector segment if the authored spawn point is blocked), builds the initial `EnemyRoutePlan`, and registers with `AliveEnemyTracker`, `EnemyCrowdService`, `EnemyCrowdPriorityService`, and `EnemyMovementSimulationService`.

**Live enemy tracking — `AliveEnemyTracker`.** A simple `HashSet<EnemyUnit>` with `AliveCountChanged` events. `EnemyRuntimeService` uses it during save/restore (`CopyTrackedEnemiesNonAlloc`) to enumerate all live enemies for state capture. `WaveSpawner` validation calls `AliveEnemyTracker.AliveCount` indirectly.

**Enemy death / goal-reach.** When a `HealthModule` health reaches zero, `EnemyDeathController` calls `EnemyUnit.DeactivateForDeath()`, which calls `DeactivateRuntimeTracking` — unregistering from all four services and nulling the references. When an enemy reaches the final path point, `DeactivateForGoalReached()` takes the same path. In both cases the GameObject is either destroyed by `EnemyDeathController` or by `EnemyUnit` itself (goal path).

**Save/restore.** `WaveManager` implements `IPersistable` and serializes `WaveManagerState` (current wave number, countdown, active/upcoming/history indices). `WaveSpawner` serializes `WaveSpawnerState` (spawn sequence progress, entry/within-entry indices, spawn timer). `EnemyRuntimeService` serializes `EnemyRuntimeState` (an array of `EnemyRuntimeEnemyState`, one per live enemy), which includes world position, health, checkpoint index, surface level, stall state, and inventory. On restore, `EnemyRuntimeService.RestoreState` instantiates each enemy's prefab at the saved position and calls `EnemyUnit.RestoreState(state)`.

## Key Classes & Files

| Class | File (relative to Assets/) | Role |
|---|---|---|
| `WaveManager` | `_Project/Scripts/Waves/WaveManager.cs` | Wave schedule, selection, countdown, run/wave lifecycle state |
| `WaveManagerState` | `_Project/Scripts/Waves/WaveManagerState.cs` | Serializable save data for WaveManager |
| `WaveSpawner` | `_Project/Scripts/Waves/WaveSpawner.cs` | Drives per-enemy spawn timing from the active WaveDefinition |
| `WaveSpawnerState` | `_Project/Scripts/Waves/WaveSpawnerState.cs` | Serializable save data for WaveSpawner |
| `WaveDefinition` | `_Project/Scripts/Waves/WaveDefinition.cs` | ScriptableObject; `AutoStartDelaySeconds`, `SelectionWeight`, `Entries[]` |
| `WaveSetDefinition` | `_Project/Scripts/Waves/WaveSetDefinition.cs` | ScriptableObject; ordered array of WaveDefinition assets |
| `WaveSpawnEntry` | `_Project/Scripts/Waves/WaveSpawnEntry.cs` | Per-entry data: `EnemyPrefab`, `Count`, `SpawnIntervalSeconds`, `SpawnPointIndex` |
| `EnemyRuntimeService` | `_Project/Scripts/Waves/EnemyRuntimeService.cs` | Instantiates/restores enemies; owns save/restore of all live enemy state |
| `EnemyRuntimeState` | `_Project/Scripts/Waves/EnemyRuntimeState.cs` | Serializable array of EnemyRuntimeEnemyState |
| `EnemyRuntimeEnemyState` | `_Project/Scripts/Waves/EnemyRuntimeEnemyState.cs` | Per-enemy serialized state (position, health, checkpoint, stall data, inventory) |
| `EnemyPrefabCatalog` | `_Project/Scripts/Waves/EnemyPrefabCatalog.cs` | ScriptableObject; maps `EnemyId` strings to prefab GameObjects |
| `EnemyPrefabCatalogEntry` | `_Project/Scripts/Waves/EnemyPrefabCatalogEntry.cs` | Single catalog entry (id + prefab reference) |
| `AliveEnemyTracker` | `_Project/Scripts/Waves/AliveEnemyTracker.cs` | Singleton HashSet of all currently alive EnemyUnit instances |
| `EnemyDeathController` | `_Project/Scripts/Waves/EnemyDeathController.cs` | HealthModule death handler; triggers DeactivateForDeath and death presentation |
| `EnemySaveIdentity` | `_Project/Scripts/Waves/EnemySaveIdentity.cs` | Component holding the string EnemyId that ties a prefab to a catalog entry |
| `EnemyUnit` (base) | `_Project/Scripts/Waves/EnemyUnit.cs` | Initialization, state capture/restore, deactivation, service registration |

## Integration Points

- **Called by:** `GameplaySimulationService.CombatTicked` drives both `WaveManager` (countdown tick) and `WaveSpawner` (spawn tick). `WaveManager.StateChanged` triggers `WaveSpawner.HandleWaveStateChanged`. Player UI calls `WaveManager.StartNextWaveNow()` or `WaveManager.BeginNewRun()` / `WaveManager.StopRun()`.
- **Calls into:** `EnemyPathService` (spawn point world position, route plans, spawn count validation). `EnemyRuntimeService.SpawnNewWaveEnemy` → `EnemyUnit.Initialize`. `AudioManager.PlayWaveStartSfx` on wave begin. `GameManager.HandleEnemyReachedGoal` when an enemy reaches the goal. `SaveManager` for persistence registration.
- **Shared state / data contracts:** `EnemyUnit.WaveSequenceNumber` (= `WaveManager.CurrentWaveNumber` at spawn time) is consumed by `EnemyCrowdPriorityService` for priority decisions. `AliveEnemyTracker.AliveCount` is read by UI and by `EnemyRuntimeService` during save. `EnemyPrefabCatalog` is the single source of truth mapping string enemy IDs to prefabs — both `WaveSpawner` (validation) and `EnemyRuntimeService` (spawn + restore) rely on it.

## Debug Guide

**Wave never starts / stays at countdown.**
- Confirm `WaveManager.IsRunActive` and `objectiveStructureService.HasPlacedObjective` are both true. The countdown only ticks when both are true and `isWaveActive` is false.
- If `upcomingWaveDefinitionIndices` is empty despite `IsRunActive`, `EnsureUpcomingQueueFilled` failed to select a candidate — check whether `preventImmediateRepeat` + `rollingConstraintWindowSize` / `maxOccurrencesPerWindow` constraints are too restrictive for the number of available wave definitions. The error "could not find an eligible wave definition" will be logged.

**Enemy not spawning when wave is active.**
- Check `WaveSpawner.isSpawnSequenceActive`. If false, `HandleWaveStateChanged` was not triggered or `BeginWave` was never called. Confirm `WaveManager.StateChanged` is firing.
- If `secondsUntilNextSpawn` stays positive, `GameplaySimulationService.CombatTicked` may not be firing (game paused or simulation disabled).

**Spawn crash — "spawn entry prefab is missing EnemySaveIdentity" / "enemy is not present in EnemyPrefabCatalog".**
- The `WaveSpawnEntry.EnemyPrefab` must have an `EnemySaveIdentity` component with an `EnemyId` that exists in the `EnemyPrefabCatalog` assigned to `EnemyRuntimeService`. These two must match. Adding a new enemy type requires both a prefab with `EnemySaveIdentity` and a matching catalog entry.

**Enemies disappear on save-restore.**
- `EnemyRuntimeService.RestoreState` calls `ClearRuntime()` first, destroying all live enemies, then re-instantiates from saved state. If restore is called before `ConfigureRuntimeRoot` has been called by `WaveSpawner.Awake`, an exception is thrown. Load order: `WaveSpawner.Awake` must fire before any `RestoreState` call.
- If an enemy's saved `EnemyId` does not match the `EnemySaveIdentity.EnemyId` on the prefab retrieved from the catalog, a "RestoreState enemy mismatch" error fires. This happens when catalog entries or prefab identities are renamed after a save was written.

**Wave history / selection producing unexpected repetitions.**
- `WaveManager` stores `recentWaveDefinitionHistory` (capped at `rollingConstraintWindowSize - 1` entries) in save state. If a save was created with a different `rollingConstraintWindowSize`, `RestoreState` will reject the mismatch with "received oversized recent wave history". Changing these values requires clearing existing saves or migrating them.

## Known Issues / Gotchas

- `WaveManager.CompleteActiveWave` is called by `WaveSpawner` after the last spawn is queued, not after the last enemy dies. The countdown for the next wave begins while enemies from the current wave are still alive. This is intentional design but can be confusing when debugging wave pacing.
- `WaveSpawner.HandleWaveStateChanged` is guarded by `GameplaySimulationService.IsExternalPauseActive`. If a wave becomes active while the game is externally paused, `BeginWave` is not called and the spawner will be out of sync with `WaveManager`. Resume-from-pause must ensure `HandleWaveStateChanged` is re-evaluated.
- There is no maximum wave count — waves are generated indefinitely by the rolling weighted-random selector. The game ends only when the run is explicitly stopped (`StopRun`, `FailCurrentRun`) or the player loses.
- `EnemyDeathPresentationService` and `EnemyDeathSequenceView` handle the visual death presentation independently from `EnemyUnit.DeactivateForDeath`. The tracking deregistration and the visual effect run in parallel; destroying the GameObject in `EnemyDeathController` while the presentation plays is safe because tracking is already cleaned up by `DeactivateForDeath` before the controller proceeds.

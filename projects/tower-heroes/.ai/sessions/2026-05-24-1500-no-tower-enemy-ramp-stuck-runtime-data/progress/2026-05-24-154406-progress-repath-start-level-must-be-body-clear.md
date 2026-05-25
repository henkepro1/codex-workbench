# Progress: Repath Start Level Must Be Body-Clear

## Runtime Finding

The latest repro failed again at:

`PF_Enemy_Nastia Position='(3.51, -2.09, 0.00)', CurrentSurfaceLevel='0', NextCheckpointIndex='0'`

Detailed inspection showed:

- The position resolves to `L0:(57,29)` and `IsWorldPositionClearForBodyAtLevel(L0) == false`.
- The same XY resolves on level 1 and `IsWorldPositionClearForBodyAtLevel(L1) == true`.
- The rebuilt route had `wp0 L0 (3.510,-2.090) clear=false`, so the canonical route was rebuilt from a body-invalid level.

The connector-owned clearance helper agreed with general body clearance:

- `IsConnectorOwnedTraversalSurfaceCircleClear(L0, connector.l0_to_l1.ramp) == false`
- blocking subcell was `L0:(57,30)`.

## Root Cause Candidate

`ResolveRepathStartLevel()` used broad `TryResolveCurrentLevelSubcell(...)`. That helper prefers route/segment levels and can resolve a subcell on the wrong level even when the enemy body is not legal on that level.

For ramp/connector overlap positions, this allowed a rebuilt route to start on level 0 even though the current body was only legal on level 1.

## Change

Patched `Assets/_Project/Scripts/Waves/EnemyUnitStallRecovery.cs`.

- `ResolveRepathStartLevel()` now only returns a level if:
  - the current position resolves on that explicit level, and
  - `IsWorldPositionClearForBodyAtLevel(currentPosition, level)` is true.
- It checks `currentSurfaceLevel` first, then explicit current segment start/end levels.
- It no longer uses broad `TryResolveCurrentLevelSubcell(...)` for route rebuild level selection.

This is a route-level correctness fix. It does not relocate, snap, teleport, ghost, or recover an enemy.

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` succeeded.
- Unity `validate_script` for `EnemyUnitStallRecovery.cs` succeeded with zero diagnostics.
- Unity refresh completed and editor reported ready.

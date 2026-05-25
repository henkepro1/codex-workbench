# Progress: Connector Exit Hard Clearance

## Context

Fresh runtime MCP data showed the ramp traversal looked smoother but still paused or stuck at the handoff from connector space to regular ground.

## Evidence

- Solo `PF_Enemy_Nastia` had `neighbors=0`, `bodyClear=True`, and connector-owned clear at `L1:(54,31)`.
- Active route segment was `wp[1]` in connector-routeable `L1:(54,31)` to `wp[2]` regular ground `L1:(54,32)`.
- `ResolveBestDisplacement` accepted the primary movement, but final hard body clearance zeroed the displacement.
- Direct probe showed `genericSameLevel req=True`, `connectorSameLevel req=False`, and `hardClear req=False` because the candidate entered regular ground.

## Change

- `EnemyUnitMovement.CanTraverseSameLevelHardBodyClearance` now attempts connector-routeable same-level clearance first.
- If that fails because the movement exits connector-routeable space into regular same-level ground, it verifies the current connector body is connector-owned clear and then uses regular same-level blocked-sample clearance for the exit segment.

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` passed with existing MSB3277 warnings.
- Unity script validation passed for `EnemyUnitMovement.cs`.
- Unity refresh completed and the editor reported ready.

## Follow-Up

Fresh Play verification is required from both spawn directions. Also recheck narrow tower-built passage and enemy-enemy pushing through the ramp.

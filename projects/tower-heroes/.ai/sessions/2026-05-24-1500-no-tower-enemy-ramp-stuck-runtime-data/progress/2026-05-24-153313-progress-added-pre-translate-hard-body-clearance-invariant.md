# Progress: Added Pre-Translate Hard Body Clearance Invariant

## Context

The latest no-tower ramp repro failed with an enemy at `L0:(57,29)` whose route plan was still routeable by point/subcell, but whose body overlapped blocked ramp-side subcell `L0:(57,30)`. The canonical guide points and same-level guide segments were clear, so the remaining bug candidate is that a same-level connector displacement can be accepted and committed even when the final body footprint is not clear.

## Change

Patched `Assets/_Project/Scripts/Waves/EnemyUnitMovement.cs` so same-level movement is revalidated immediately before `TranslateWorldPosition(...)`.

- Same-level connector movement is checked with `TryCanTraverseConnectorRouteableSameLevelDisplacement(...)`.
- Non-connector same-level movement is checked with `TryCanTraverseSameLevelUsingBlockedSample(...)`.
- If the full displacement is not body-clear, the code binary-searches the largest legal prefix before committing movement.
- If no legal prefix exists, no transform movement is committed and the post-move clear-state cache is invalidated.

This is a hard canonical movement constraint, not stall recovery, teleporting, snapping, ghosting, or relocation.

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` succeeded.
- Unity `validate_script` for `EnemyUnitMovement.cs` succeeded with zero diagnostics.
- Unity refresh completed and editor reported ready.

## Next Runtime Check

Run the no-tower ramp repro again. Expected result: enemies should no longer enter a body-invalid ramp-side overlap before failing. If movement still throttles or stalls, the next data should show zero-displacement from the canonical same-level constraint instead of a post-move blocked-overlap exception.

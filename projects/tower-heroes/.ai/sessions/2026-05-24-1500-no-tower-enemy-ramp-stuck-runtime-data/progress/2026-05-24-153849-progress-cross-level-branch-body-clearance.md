# Progress: Cross-Level Branch Now Requires Body Clearance

## Runtime Finding

After the pre-translate same-level guard, the next no-tower repro failed at:

`PF_Enemy_Ivanna Position='(0.91, 0.00, 0.00)', CurrentSurfaceLevel='1', NextCheckpointIndex='1'`

Live route dump showed:

- `wp0 L1 (0.910,-0.004) bodyClear=False`
- `wp1 L1 (0.890,-0.110) bodyClear=True`
- Segment `wp0 -> wp1` was not body-clear.

Spawn positions were checked separately and were body-clear on their intended routes, so this was not a wrong-plane spawn issue. The enemy reached a body-invalid level-1 ramp/portal position during traversal.

## Root Cause Found

`TryAcceptActiveConnectorCrossLevelDisplacement(...)` accepted cross-level connector movement by corridor geometry only. It set `verifiedClearEndPosition = true` using `currentSurfaceLevel`, without checking whether the candidate body footprint was clear on the level side the candidate had actually progressed into.

That allowed the canonical cross-level handoff to commit a body-invalid ramp-side/portal position, then route rebuilding used that invalid current position as `wp0`.

## Change

Patched `Assets/_Project/Scripts/Waves/EnemyUnitCrossLevelTraversal.cs`.

- Resolves cross-level transition metadata and connector id for the active segment.
- After corridor acceptance, validates the accepted candidate with `IsConnectorOwnedTraversalSurfaceCircleClear(...)`.
- Candidate surface level is selected from progress along the cross-level segment: first half uses start level, second half uses end level.
- If the full candidate is not body-clear, binary-searches the largest body-clear prefix.
- Only marks post-move clearance verified for the candidate's verified surface level.

This is a canonical movement constraint fix, not recovery, snapping, teleporting, ghosting, or relocation.

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` succeeded.
- Unity `validate_script` for `EnemyUnitCrossLevelTraversal.cs` succeeded with zero diagnostics.
- Unity refresh completed and editor reported ready.

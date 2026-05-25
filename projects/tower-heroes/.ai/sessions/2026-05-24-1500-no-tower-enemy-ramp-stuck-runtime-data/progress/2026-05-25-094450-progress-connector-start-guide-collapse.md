# Progress: Connector Start Guide Collapse

## Context

After the connector-owned body-clear surface fix, the runtime MCP snapshot showed enemies clearing the previous ramp authority error but bunching at the first route points after the ramp. There were no gameplay error logs.

## Evidence

- `PF_Enemy_Ivanna` and `PF_Enemy_Nastia` pairs were body-clear on their current route levels.
- Each route started with `wp[0]` at the enemy's actual connector-subcell position.
- `wp[1]` mapped to the same connector routeable subcell as `wp[0]`, while `wp[2]` was regular ground.
- `HasReachedCurrentPathPoint` was false, so enemies were being forced through a small intra-subcell guide detour before leaving connector ownership.

## Change

- `EnemyPathService.BuildRoutePlan` now makes the first route point follow the real route start when the first route subcell is connector-routeable.
- `DynamicRoutePlanTemplate.CreateRoutePlan` preserves that same first-point shape for cached dynamic route plans and recomputes remaining distance for the changed point.

## Verification

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` passed with existing MSB3277 warnings.
- Unity script validation passed for `EnemyPathService.cs` and `DynamicRoutePlanTemplate.cs`.
- Unity script refresh completed and the editor reported ready.

## Follow-Up

Fresh Play verification is still required from both spawn directions, plus narrow tower-built passage and enemy-enemy pushing through the ramp.

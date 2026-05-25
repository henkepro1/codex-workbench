# Ramp Traversal Root-Fix Protocol

This rule applies to every Tower Heroes enemy movement change involving ramps, connector routeable subcells, cross-level traversal, stuck enemies, narrow passages, route rebuilds, or movement performance around connector paths.

## Non-Negotiable Goal

The ramp must work as normal gameplay, not as a recovery case.

An enemy in valid routeable ramp space must continue through the connector by canonical movement rules. It must not rely on teleporting, snapping, ghosting, disabling collision, route-origin relocation, stall recovery, or bypass movement.

## Canonical Ramp Invariant

While an enemy is on a connector routeable or connector cross-level segment:

- Connector lane progress and body-clear checks own movement.
- Generic static obstacle repulsion must not steer the enemy laterally off the authored connector lane.
- Enemy-enemy collision and pushing may affect movement, but only inside the legal connector/body-clear constraints.
- Current surface level must be chosen from explicit route/connector levels and must be body-clear for the enemy body.
- Route rebuild origins must be body-clear on the selected level.
- Path-point progression must not advance past unfinished ramp lane travel just because a broad subcell or checkpoint condition matched.

## Required Step Gate

Before every code edit in this area, the agent must write down, in the working update or session note:

1. The exact invariant being protected.
2. The runtime evidence or code evidence that proves the current step is needed.
3. The exact file/function being changed.
4. Why the change is not a workaround.

If any of those four cannot be stated clearly, do not edit code.

## Required Runtime Snapshot For Any Stuck Repro

For a stuck or throttling ramp repro, capture the smallest useful MCP snapshot:

- Console errors and stack traces.
- Enemy name, position, current surface level, checkpoint index, path point index.
- Body-clear result for every route level relevant to the current route.
- Nearby route world points and their levels.
- Requested displacement, applied displacement, steering vectors, neighbor count, and accepted constraint branch when available.
- Whether the current position is body-clear on an alternate route level without changing XY.

Do not patch from a screenshot or verbal stuck report alone when MCP data can be captured.

## Patch Order

Patch in this order unless the latest snapshot proves a different earlier invariant is violated:

1. Connector movement authority.
2. Surface-level selection.
3. Route progress/promotion.
4. Same-level connector body-clear constraint.
5. Cross-level connector body-clear constraint.
6. Route rebuild origin/level selection.
7. Performance of the above after correctness is proven.

Do not start at stall recovery or fallback behavior.

## Forbidden Fix Shapes

Do not implement or reintroduce:

- Teleport-to-clear-position behavior.
- Snap-to-guide-point behavior outside normal movement displacement.
- Ghosting through blockers.
- Disabling enemy-enemy blocking to pass ramps.
- Increasing body clearance by ignoring blocked cells.
- Accepting point/subcell routeability when the body footprint is not clear.
- Broad preferred/fallback level resolution inside hard traversal checks.
- Stall recovery as the primary answer to a ramp movement failure.

## Verification Gate

A ramp movement change is not accepted until:

- `dotnet build D:\GameProjects\TowerHeroes(x)\TowerHeroes\Assembly-CSharp.csproj --no-restore` succeeds.
- Relevant Unity script validation succeeds.
- No-tower ramp traversal is tested from both spawn directions.
- Narrow tower-built passage is tested separately.
- Enemy-enemy pushing through the ramp remains enabled.
- The result is recorded in the active project session when a project-session is active.

# Assigned connector route start validation covers both random spawns

Date: 2026-05-25T01:15:30+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented final assigned route-start validation. Initial route assignment now carries the resolved connector route-start subcell returned by spawn correction, builds the route from that actual subcell, validates currentRoutePlan.WorldPoints[0] equals cachedWorldPosition, and validates connector-owned clearance on the assigned start before simulation. Connector spawn correction now searches the same-level same-connector route prefix until the authored cross-level transition, so it may enter the next same-connector routeable subcell when the portal endpoint itself is body-invalid. RefreshPath(true) no longer installs cachedEnemyPathService.GetRoutePlan(spawnPointIndex) directly; it uses the same invariant path.

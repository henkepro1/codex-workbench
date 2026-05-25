# Connector-owned spawn start clearance root fix

Date: 2026-05-25T01:04:21+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented connector-routeable spawn-start validation in EnemyUnit. ResolveBodyClearSpawnWorldPositionOnRouteStart now uses connector-owned body clearance for connector routeable start subcells. If wp0 is blocked, it searches only along the authored first segment wp0->wp1, on the authored start level, same route start subcell, and same connector id, then binary-searches the nearest connector-owned clear point before registration. Validation after route initialization also uses connector-owned clearance. Diagnostics now include connector id, connector-owned clear result, and blocking subcell. No movement repair, teleport, snap, ghost, stall recovery, broad level scan, or route refresh escape was added.

# Patched connector same-level path progress

Date: 2026-05-24T15:16:22+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Root cause identified in EnemyUnitMovement.HasReachedRoutePathPoint: same-level connector routeable path points advanced on broad subcell membership/route-order membership before the enemy physically reached the connector guide point. On the narrow ramp this can switch the active segment early, leave the enemy off the guide lane, and make body clearance fail against adjacent blocked ramp side cells. Patched same-level connector membership checks to defer to the normal physical arrival/projection checks instead of returning reached immediately.

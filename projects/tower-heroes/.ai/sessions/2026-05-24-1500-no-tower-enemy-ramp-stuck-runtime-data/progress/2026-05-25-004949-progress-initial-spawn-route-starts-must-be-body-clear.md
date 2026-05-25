# Initial spawn route starts must be body-clear

Date: 2026-05-25T00:49:49+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented the spawn-start invariant for the ramp stuck repro: EnemyUnit now builds the initial route from a body-clear spawn position on the authored route start level before registration/simulation. If the authored spawn XY is body-invalid on its own route start level, initialization searches only for a body-clear point on that same level and same start subcell; if none exists it fails before the enemy is registered. The first blocked-overlap tick is no longer used to repair invalid spawn state (requiresBlockedOverlapResolution=false after initialization). No teleport/snap/ghost/stall recovery/route-refresh escape was added.

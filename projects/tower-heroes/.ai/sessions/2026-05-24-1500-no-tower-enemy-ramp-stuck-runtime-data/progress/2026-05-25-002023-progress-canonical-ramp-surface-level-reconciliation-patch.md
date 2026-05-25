# Canonical ramp surface level reconciliation patch

Date: 2026-05-25T00:20:23+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Implemented the requested root fix in EnemyUnitMovement: after movement/progress points, an invalid currentSurfaceLevel is reconciled only by scanning explicit route levels at the same XY. Exactly one body-clear route level switches currentSurfaceLevel and refreshes route/progress; zero or multiple clear levels fail fast. Path progress now refuses to advance through route points while the current body is invalid on currentSurfaceLevel. No transform movement, snap, teleport, ghosting, stall recovery, or enemy-enemy collision changes were added.

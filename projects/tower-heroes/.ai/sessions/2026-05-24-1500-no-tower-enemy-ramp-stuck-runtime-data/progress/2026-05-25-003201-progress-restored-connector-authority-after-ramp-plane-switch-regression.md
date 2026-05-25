# Restored connector authority after ramp plane-switch regression

Date: 2026-05-25T00:32:01+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Replaced the broad route-level currentSurfaceLevel reconciliation in EnemyUnitMovement with connector-authoritative reconciliation. Invalid current surface level can now be corrected only when the active cross-level connector corridor or same-level connector routeable segment proves the current XY is legal under connector-owned body clearance. Removed route refresh from this reconciliation path and removed broad body-clear candidate level switching from blocked-overlap handling. If invalid state is outside connector authority, it now fails fast with route level body-clear diagnostics, segment levels, path index, movement vectors, neighbor count, and branch context.

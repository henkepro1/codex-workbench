# Removed fake canonical connector route origins

Date: 2026-05-24T15:24:30+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

User correctly pointed out the canonical path pipeline is wrong. Live dump showed routeFromHere=true while bodyClear=false on connector routeable ramp cells. Root issue found in route planning: connector-routeable repath/reuse could build a route from a canonical/snapped guide point while the enemy transform stayed at a different current world position, creating a route plan whose first world point lied about the actual body location. Patched EnemyUnitRoutePlanning and EnemyUnitCrossLevelTraversal to build/reuse connector route plans from the real current world position only when CanUseCurrentWorldPositionAsRouteableRepathOrigin already proves body-clear routeability. Removed the movement overlap branch that accepted subcell routeability while body clearance was false.

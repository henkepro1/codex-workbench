# Root cause identified as obstacle repulsion fighting connector lane

Date: 2026-05-25T00:07:58+02:00
Kind: progress
Project: tower-heroes
Session: 2026-05-24-1500-no-tower-enemy-ramp-stuck-runtime-data

## Note

Paused runtime snapshot showed the stuck Ivanna had no crowd steering, curLevel=1 bodyClear=false, repathLevel=0, nextPathPointIndex=58, and movementSteeringCacheObstacleRepulsion=(-14.28, 12.67). Static obstacle repulsion was pushing the enemy laterally/upward off the ramp guide lane while on connector-routeable subcells. Patched CalculateObstacleRepulsion to return zero on connector-routeable subcells so the authored connector route and hard body-clear constraints govern ramp traversal; enemy-enemy pushing remains active.
